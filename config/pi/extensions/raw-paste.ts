import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";
import { platform } from "node:process";
import { spawnSync } from "node:child_process";
import { CustomEditor, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getImageDimensions, Image, Text, type ImageDimensions } from "@earendil-works/pi-tui";

const PASTE_START = "\x1b[200~";
const PASTE_END = "\x1b[201~";
const PASTE_END_LEN = PASTE_END.length;
const BACKSPACE = "\x7f";
const PASTE_MARKER_AT_END = /\[paste #\d+( (\+\d+ lines|\d+ chars))?\]$/;
const IMAGE_PLACEHOLDER_REGEX = /\[#image \d+\]/g;
const MAX_IMAGE_BYTES = 64 * 1024 * 1024;

type SupportedImageMimeType = "image/png" | "image/jpeg" | "image/webp" | "image/gif";

type ImageAttachment = {
	id: number;
	placeholder: string;
	originalPath: string;
	mimeType: SupportedImageMimeType;
	data: string;
	dimensions?: ImageDimensions;
	createdAt: number;
};

type LoadedImage = Omit<ImageAttachment, "id" | "placeholder" | "createdAt">;

type LoadImageResult =
	| { ok: true; image: LoadedImage }
	| { ok: false; reason: "missing" | "not-file" | "too-large" | "unsupported" | "read-error"; path: string };

type EditorLike = CustomEditor & {
	getLines?: () => string[];
	getCursor?: () => { line: number; col: number };
	insertTextAtCursor?: (text: string) => void;
};

type RawPasteState = {
	autoRawPasteBuffer: string;
	isInAutoRawPaste: boolean;
	imagePasteBuffer: string | undefined;
};

type PathToken = {
	value: string;
	start: number;
	end: number;
	bare: boolean;
};

class AttachmentStore {
	private nextId = 1;
	private readonly attachments = new Map<string, ImageAttachment>();

	clear(): void {
		this.nextId = 1;
		this.attachments.clear();
	}

	add(image: LoadedImage): ImageAttachment {
		const id = this.nextId++;
		const attachment: ImageAttachment = {
			...image,
			id,
			placeholder: `[#image ${id}]`,
			createdAt: Date.now(),
		};
		this.attachments.set(attachment.placeholder, attachment);
		return attachment;
	}

	get(placeholder: string): ImageAttachment | undefined {
		return this.attachments.get(placeholder);
	}

	list(): ImageAttachment[] {
		return [...this.attachments.values()].sort((a, b) => a.id - b.id);
	}

	matchingPlaceholders(text: string): ImageAttachment[] {
		return this.list()
			.map((attachment) => ({ attachment, index: text.indexOf(attachment.placeholder) }))
			.filter((match) => match.index >= 0)
			.sort((a, b) => a.index - b.index)
			.map((match) => match.attachment);
	}
}

const PATCHED = Symbol.for("pi.raw-paste.decorated");
const WINDOWS_DRIVE_PATH = /^([a-zA-Z]):[\\/](.*)$/;

function createState(): RawPasteState {
	return {
		autoRawPasteBuffer: "",
		isInAutoRawPaste: false,
		imagePasteBuffer: undefined,
	};
}

function notify(ctx: ExtensionContext, message: string, type: "info" | "warning" = "info"): void {
	if (!ctx.hasUI) return;
	ctx.ui.notify(message, type);
}

function normalizeRawPaste(content: string): string {
	return content.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function detectImageMimeType(bytes: Uint8Array): SupportedImageMimeType | undefined {
	if (
		bytes.length >= 8 &&
		bytes[0] === 0x89 &&
		bytes[1] === 0x50 &&
		bytes[2] === 0x4e &&
		bytes[3] === 0x47 &&
		bytes[4] === 0x0d &&
		bytes[5] === 0x0a &&
		bytes[6] === 0x1a &&
		bytes[7] === 0x0a
	) {
		return "image/png";
	}
	if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
		return "image/jpeg";
	}
	if (
		bytes.length >= 6 &&
		bytes[0] === 0x47 &&
		bytes[1] === 0x49 &&
		bytes[2] === 0x46 &&
		bytes[3] === 0x38 &&
		(bytes[4] === 0x37 || bytes[4] === 0x39) &&
		bytes[5] === 0x61
	) {
		return "image/gif";
	}
	if (
		bytes.length >= 12 &&
		bytes[0] === 0x52 &&
		bytes[1] === 0x49 &&
		bytes[2] === 0x46 &&
		bytes[3] === 0x46 &&
		bytes[8] === 0x57 &&
		bytes[9] === 0x45 &&
		bytes[10] === 0x42 &&
		bytes[11] === 0x50
	) {
		return "image/webp";
	}
	return undefined;
}

function dimensionsForImage(data: string, mimeType: SupportedImageMimeType): ImageDimensions | undefined {
	return getImageDimensions(data, mimeType) ?? undefined;
}

function isWindowsDrivePath(value: string): boolean {
	return WINDOWS_DRIVE_PATH.test(value);
}

function isWindowsUncPath(value: string): boolean {
	return value.startsWith("\\\\") && value.length > 2;
}

function isWindowsLikePath(value: string): boolean {
	return isWindowsDrivePath(value) || isWindowsUncPath(value);
}

function isPathLike(value: string): boolean {
	return (
		value.startsWith("/") ||
		value.startsWith("~/") ||
		value === "~" ||
		value.startsWith("./") ||
		value.startsWith("../") ||
		isWindowsLikePath(value)
	);
}

function isWsl(): boolean {
	if (platform !== "linux") return false;
	if (process.env.WSL_DISTRO_NAME || process.env.WSL_INTEROP) return true;
	try {
		return /microsoft|wsl/i.test(readFileSync("/proc/version", "utf8"));
	} catch {
		return false;
	}
}

function windowsToWslPath(windowsPath: string): string {
	const driveMatch = WINDOWS_DRIVE_PATH.exec(windowsPath);
	if (driveMatch) {
		const drive = driveMatch[1]!.toLowerCase();
		const rest = driveMatch[2]!.replace(/\\/g, "/");
		return rest.length > 0 ? `/mnt/${drive}/${rest}` : `/mnt/${drive}`;
	}
	if (isWindowsUncPath(windowsPath)) return windowsPath.replace(/\\/g, "/");
	return windowsPath;
}

function resolveImagePath(input: string, cwd: string): string {
	if (input === "~") return homedir();
	if (input.startsWith("~/")) return resolve(homedir(), input.slice(2));
	if (isWindowsLikePath(input)) {
		if (platform === "win32") return input;
		if (isWsl()) return windowsToWslPath(input);
		return input;
	}
	if (isAbsolute(input)) return input;
	return resolve(cwd, input);
}

function shellUnescape(input: string): string {
	let result = "";
	for (let i = 0; i < input.length; i++) {
		const char = input[i]!;
		if (char === "\\" && i + 1 < input.length) result += input[++i]!;
		else result += char;
	}
	return result;
}

function startsWithWindowsPath(text: string, index: number): boolean {
	return (
		(index + 2 < text.length &&
			/[a-zA-Z]/.test(text[index]!) &&
			text[index + 1] === ":" &&
			(text[index + 2] === "\\" || text[index + 2] === "/")) ||
		(index + 1 < text.length && text[index] === "\\" && text[index + 1] === "\\")
	);
}

function tokenizePathLikeText(text: string): PathToken[] {
	const tokens: PathToken[] = [];
	let index = 0;
	while (index < text.length) {
		const char = text[index]!;
		if (/\s/.test(char)) {
			index++;
			continue;
		}

		const start = index;
		if (char === "'" || char === '"') {
			const quote = char;
			index++;
			const windowsMode = startsWithWindowsPath(text, index);
			let value = "";
			let closed = false;
			while (index < text.length) {
				const current = text[index]!;
				if (!windowsMode && current === "\\" && quote === '"' && index + 1 < text.length) {
					value += text[index + 1]!;
					index += 2;
					continue;
				}
				if (current === quote) {
					index++;
					closed = true;
					break;
				}
				value += current;
				index++;
			}
			if (closed && isPathLike(value)) tokens.push({ value, start, end: index, bare: false });
			continue;
		}

		const windowsMode = startsWithWindowsPath(text, index);
		let rawValue = "";
		while (index < text.length) {
			const current = text[index]!;
			if (/\s/.test(current)) break;
			if (!windowsMode && current === "\\" && index + 1 < text.length) {
				rawValue += current + text[index + 1]!;
				index += 2;
				continue;
			}
			rawValue += current;
			index++;
		}
		const value = windowsMode ? rawValue : shellUnescape(rawValue);
		if (isPathLike(value)) tokens.push({ value, start, end: index, bare: true });
	}
	return tokens;
}

function loadImageFromPath(inputPath: string, cwd: string, maxBytes = MAX_IMAGE_BYTES): LoadImageResult {
	const path = resolveImagePath(inputPath, cwd);
	try {
		if (!existsSync(path)) return { ok: false, reason: "missing", path };
		const stat = statSync(path);
		if (!stat.isFile()) return { ok: false, reason: "not-file", path };
		if (stat.size > maxBytes) return { ok: false, reason: "too-large", path };
		const bytes = readFileSync(path);
		const mimeType = detectImageMimeType(bytes);
		if (!mimeType) return { ok: false, reason: "unsupported", path };
		const data = bytes.toString("base64");
		return {
			ok: true,
			image: { originalPath: path, mimeType, data, dimensions: dimensionsForImage(data, mimeType) },
		};
	} catch {
		return { ok: false, reason: "read-error", path };
	}
}

function tryExtendBareToken(
	text: string,
	token: PathToken,
	attempt: (path: string) => LoadImageResult,
): { end: number; result: LoadImageResult } {
	let value = token.value;
	let end = token.end;
	let lastResult = attempt(value);
	if (lastResult.ok || lastResult.reason === "too-large" || !token.bare) return { end, result: lastResult };

	let scan = end;
	for (let i = 0; i < 8; i++) {
		let wsEnd = scan;
		while (wsEnd < text.length) {
			const ch = text[wsEnd]!;
			if (ch === "\n" || ch === "\r" || !/\s/.test(ch)) break;
			wsEnd++;
		}
		if (wsEnd === scan) break;

		let wordEnd = wsEnd;
		while (wordEnd < text.length && !/\s/.test(text[wordEnd]!)) wordEnd++;
		if (wordEnd === wsEnd) break;

		const nextWord = shellUnescape(text.slice(wsEnd, wordEnd));
		if (isPathLike(nextWord)) break;

		const extendedValue = value + text.slice(scan, wsEnd) + nextWord;
		const candidate = attempt(extendedValue);
		scan = wordEnd;
		if (candidate.ok || candidate.reason === "too-large") return { end: wordEnd, result: candidate };
		value = extendedValue;
		end = wordEnd;
		lastResult = candidate;
	}
	return { end, result: lastResult };
}

function replaceImagePathsInText(
	text: string,
	options: { cwd: string; store: AttachmentStore; notify: (message: string) => void },
): { text: string; replaced: number; accepted: ImageAttachment[] } {
	const tokens = tokenizePathLikeText(text);
	if (tokens.length === 0) return { text, replaced: 0, accepted: [] };
	let output = "";
	let cursor = 0;
	let replaced = 0;
	const accepted: ImageAttachment[] = [];

	for (const token of tokens) {
		if (token.start < cursor) continue;
		const extended = tryExtendBareToken(text, token, (path) => loadImageFromPath(path, options.cwd));
		if (!extended.result.ok) {
			if (extended.result.reason === "too-large") {
				options.notify(`image-paste: image is too large and was not attached: ${extended.result.path}`);
			}
			continue;
		}
		const attachment = options.store.add(extended.result.image);
		accepted.push(attachment);
		output += text.slice(cursor, token.start) + attachment.placeholder;
		cursor = extended.end;
		replaced++;
	}
	if (replaced === 0) return { text, replaced: 0, accepted: [] };
	output += text.slice(cursor);
	return { text: output, replaced, accepted };
}

function readLinuxClipboardImage(maxBytes = MAX_IMAGE_BYTES): LoadedImage | undefined {
	const tools = [
		{ cmd: "wl-paste", args: ["--type", "image/png"] },
		{ cmd: "xclip", args: ["-selection", "clipboard", "-t", "image/png", "-o"] },
	];
	for (const tool of tools) {
		const result = spawnSync(tool.cmd, tool.args, { timeout: 3000, encoding: "buffer", maxBuffer: maxBytes });
		if (result.error || result.status !== 0 || !result.stdout || result.stdout.length === 0) continue;
		const bytes = result.stdout;
		if (bytes.length > maxBytes) return undefined;
		const mimeType = detectImageMimeType(bytes);
		if (!mimeType) continue;
		const data = bytes.toString("base64");
		return { originalPath: "clipboard.png", mimeType, data, dimensions: dimensionsForImage(data, mimeType) };
	}
	return undefined;
}

function markerImmediatelyBeforeCursor(editor: EditorLike): boolean {
	const lines = editor.getLines?.();
	const cursor = editor.getCursor?.();
	if (!lines || !cursor) return false;
	const currentLine = lines[cursor.line] ?? "";
	return PASTE_MARKER_AT_END.test(currentLine.slice(0, cursor.col));
}

function decorateEditor(
	editor: EditorLike,
	state: RawPasteState,
	ctx: ExtensionContext,
	store: AttachmentStore,
	keybindings: { matches?: (data: string, action: string) => boolean },
): EditorLike {
	const anyEditor = editor as EditorLike & { [PATCHED]?: boolean; state?: { lines: string[]; cursorLine: number; cursorCol: number }; segment?: (text: string, mode?: string) => Iterable<Intl.SegmentData>; setCursorCol?: (col: number) => void; pushUndoSnapshot?: () => void; lastAction?: unknown; historyIndex?: number };
	if (anyEditor[PATCHED]) return editor;
	anyEditor[PATCHED] = true;

	const originalHandleInput = editor.handleInput.bind(editor);
	const originalInsertTextAtCursor = editor.insertTextAtCursor?.bind(editor);
	const originalSegment = anyEditor.segment?.bind(editor);

	if (originalSegment) {
		anyEditor.segment = (text: string, mode?: string) => {
			const baseSegments = [...originalSegment(text, mode)];
			if (!text.includes("[#image ")) return baseSegments;
			const spans = [...text.matchAll(IMAGE_PLACEHOLDER_REGEX)].map((match) => ({
				start: match.index,
				end: match.index + match[0].length,
			}));
			if (spans.length === 0) return baseSegments;
			const result: Intl.SegmentData[] = [];
			let spanIndex = 0;
			for (const segment of baseSegments) {
				while (spanIndex < spans.length && spans[spanIndex]!.end <= segment.index) spanIndex++;
				const span = spans[spanIndex];
				if (span && segment.index >= span.start && segment.index < span.end) {
					if (segment.index === span.start) {
						result.push({ segment: text.slice(span.start, span.end), index: span.start, input: text });
					}
					continue;
				}
				result.push(segment);
			}
			return result;
		};
	}

	function flushRawPaste(content: string): void {
		const normalized = normalizeRawPaste(content);
		for (const char of normalized) originalHandleInput(char);
	}

	function insertText(text: string): void {
		if (!text) return;
		if (originalInsertTextAtCursor) originalInsertTextAtCursor(text);
		else for (const char of text) originalHandleInput(char);
	}

	function transformAndInsertImagePaths(text: string): boolean {
		const transformed = replaceImagePathsInText(text, {
			cwd: ctx.cwd,
			store,
			notify: (message) => notify(ctx, message, "warning"),
		});
		if (transformed.replaced === 0) return false;
		insertText(transformed.text);
		return true;
	}

	function replacePreviousPasteMarkerWithRawPaste(content: string): void {
		originalHandleInput(BACKSPACE);
		flushRawPaste(content);
		notify(ctx, "Unwrapped compressed paste into raw text.", "info");
	}

	function feedImagePaste(data: string): boolean {
		const wasBuffered = state.imagePasteBuffer !== undefined;
		if (!wasBuffered) {
			const start = data.indexOf(PASTE_START);
			if (start === -1) return false;
			const prefix = data.slice(0, start);
			state.imagePasteBuffer = data.slice(start + PASTE_START.length);
			if (!state.imagePasteBuffer.includes(PASTE_END)) {
				if (prefix) originalHandleInput(prefix);
				return true;
			}
			if (prefix) originalHandleInput(prefix);
		} else {
			state.imagePasteBuffer += data;
			if (!state.imagePasteBuffer.includes(PASTE_END)) return true;
		}

		const end = state.imagePasteBuffer.indexOf(PASTE_END);
		const content = state.imagePasteBuffer.slice(0, end);
		const remaining = state.imagePasteBuffer.slice(end + PASTE_END_LEN);
		state.imagePasteBuffer = undefined;
		if (!transformAndInsertImagePaths(content)) {
			originalHandleInput(`${PASTE_START}${content}${PASTE_END}`);
		}
		if (remaining) editor.handleInput(remaining);
		return true;
	}

	function handleAutoRawSecondPasteInput(data: string): boolean {
		let handled = false;
		if (data.includes(PASTE_START) && markerImmediatelyBeforeCursor(editor)) {
			state.isInAutoRawPaste = true;
			state.autoRawPasteBuffer = "";
			data = data.replace(PASTE_START, "");
			handled = true;
		}
		if (state.isInAutoRawPaste) {
			state.autoRawPasteBuffer += data;
			const endIndex = state.autoRawPasteBuffer.indexOf(PASTE_END);
			if (endIndex !== -1) {
				const pasteContent = state.autoRawPasteBuffer.substring(0, endIndex);
				const remaining = state.autoRawPasteBuffer.substring(endIndex + PASTE_END_LEN);
				state.autoRawPasteBuffer = "";
				state.isInAutoRawPaste = false;
				replacePreviousPasteMarkerWithRawPaste(pasteContent);
				if (remaining.length > 0) editor.handleInput(remaining);
			}
			return true;
		}
		return handled;
	}

	function deletePlaceholder(data: string): boolean {
		const isBackspace = keybindings.matches?.(data, "tui.editor.deleteCharBackward") ?? data === BACKSPACE;
		const isDelete = keybindings.matches?.(data, "tui.editor.deleteCharForward") ?? false;
		if (!isBackspace && !isDelete) return false;
		const lines = editor.getLines?.();
		const cursor = editor.getCursor?.();
		if (!lines || !cursor || !anyEditor.state) return false;
		const line = lines[cursor.line] ?? "";
		for (const match of line.matchAll(IMAGE_PLACEHOLDER_REGEX)) {
			const start = match.index;
			const end = start + match[0].length;
			const hitsBackspace = isBackspace && cursor.col > start && cursor.col <= end;
			const hitsDelete = isDelete && cursor.col >= start && cursor.col < end;
			if (!hitsBackspace && !hitsDelete) continue;
			anyEditor.pushUndoSnapshot?.();
			anyEditor.state.lines[cursor.line] = line.slice(0, start) + line.slice(end);
			anyEditor.state.cursorLine = cursor.line;
			if (anyEditor.setCursorCol) anyEditor.setCursorCol(start);
			else anyEditor.state.cursorCol = start;
			anyEditor.lastAction = null;
			anyEditor.historyIndex = -1;
			editor.onChange?.(editor.getText());
			(editor as CustomEditor).invalidate?.();
			return true;
		}
		return false;
	}

	editor.handleInput = (data: string): void => {
		if (keybindings.matches?.(data, "app.clipboard.pasteImage")) {
			const image = platform === "linux" ? readLinuxClipboardImage() : undefined;
			if (!image) {
				notify(ctx, "image-paste: clipboard image could not be attached", "warning");
				return;
			}
			insertText(store.add(image).placeholder);
			return;
		}
		if (deletePlaceholder(data)) return;
		if (handleAutoRawSecondPasteInput(data)) return;
		if (feedImagePaste(data)) return;
		originalHandleInput(data);
	};

	return editor;
}

function imagePreviewMessage(attachments: ImageAttachment[]) {
	return {
		customType: "image-paste-preview",
		content: `(attachment preview: ${attachments.map((a) => a.placeholder).join(", ")})`,
		display: true,
		details: { placeholders: attachments.map((a) => a.placeholder) },
	};
}

export default function (pi: ExtensionAPI) {
	const store = new AttachmentStore();
	let activeState: RawPasteState | null = null;
	let pendingPreview: ImageAttachment[] = [];

	pi.registerMessageRenderer<{ placeholders?: string[] }>("image-paste-preview", (message, options, theme) => {
		const placeholders = message.details?.placeholders ?? [];
		const attachments = store.list().filter((attachment) => placeholders.includes(attachment.placeholder));
		if (attachments.length === 0) return undefined;
		if (!options.expanded) {
			return new Text(
				theme.fg(
					"muted",
					attachments.length === 1 ? `Attached ${attachments[0]!.placeholder}` : `Attached ${attachments.length} images`,
				),
				0,
				0,
			);
		}
		return {
			render(width: number) {
				const lines: string[] = [];
				for (const attachment of attachments) {
					lines.push(theme.fg("muted", `Attached ${attachment.placeholder} ${attachment.originalPath}`));
					lines.push(...new Image(attachment.data, attachment.mimeType, { fallbackColor: (text) => theme.fg("muted", text) }, { maxWidthCells: 60, maxHeightCells: 16, filename: attachment.placeholder }, attachment.dimensions).render(width));
				}
				return lines;
			},
			invalidate() {},
		};
	});

	pi.on("session_start", (_event, ctx) => {
		store.clear();
		pendingPreview = [];
		if (!ctx.hasUI) return;

		const ui = ctx.ui as typeof ctx.ui & { __rawPasteSetEditorPatched?: boolean };
		if (ui.__rawPasteSetEditorPatched) return;
		ui.__rawPasteSetEditorPatched = true;

		const originalSetEditorComponent = ctx.ui.setEditorComponent.bind(ctx.ui);
		ctx.ui.setEditorComponent = (factory) => {
			if (!factory) {
				activeState = null;
				originalSetEditorComponent(undefined);
				return;
			}
			originalSetEditorComponent((tui, theme, keybindings) => {
				const state = createState();
				const editor = factory(tui, theme, keybindings) as EditorLike;
				activeState = state;
				return decorateEditor(editor, state, ctx, store, keybindings);
			});
		};
		ctx.ui.setEditorComponent((tui, theme, keybindings) => new CustomEditor(tui, theme, keybindings));
	});

	pi.on("session_shutdown", (_event, ctx) => {
		pendingPreview = [];
		activeState = null;
		if (ctx.hasUI) ctx.ui.setEditorComponent(undefined);
		store.clear();
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return { action: "continue" as const };
		const attachments = store.matchingPlaceholders(event.text);
		if (attachments.length === 0) return { action: "continue" as const };
		if (ctx.isIdle()) pendingPreview = attachments;
		else pi.sendMessage(imagePreviewMessage(attachments), { deliverAs: "followUp" });
		return {
			action: "transform" as const,
			text: event.text,
			images: [
				...(event.images ?? []),
				...attachments.map((attachment) => ({ type: "image" as const, mimeType: attachment.mimeType, data: attachment.data })),
			],
		};
	});

	pi.on("before_agent_start", () => {
		if (pendingPreview.length === 0) return;
		const message = imagePreviewMessage(pendingPreview);
		pendingPreview = [];
		return { message };
	});

}
