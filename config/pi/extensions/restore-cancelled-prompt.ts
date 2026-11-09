import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type AssistantLike = { role?: string; stopReason?: string; errorMessage?: string };
type RestorablePrompt = string | null | undefined;

let pendingPrompt: RestorablePrompt;
let activePrompt: string | undefined;
let restoredActivePrompt = false;

function isAssistantAbort(message: unknown): boolean {
	const assistant = message as AssistantLike;
	return assistant.role === "assistant" && (assistant.stopReason === "aborted" || assistant.errorMessage === "Retry cancelled");
}

function restoreActivePrompt(ctx: ExtensionContext): void {
	if (ctx.mode !== "tui") return;
	if (!activePrompt || restoredActivePrompt) return;

	const prompt = activePrompt.trim();
	if (!prompt) return;

	const current = ctx.ui.getEditorText().trim();
	let nextText: string;

	if (!current) {
		nextText = prompt;
	} else if (current === prompt || current.startsWith(`${prompt}\n\n`)) {
		nextText = current;
	} else {
		nextText = [prompt, current].join("\n\n");
	}

	ctx.ui.setEditorText(nextText);
	activePrompt = undefined;
	pendingPrompt = undefined;
	restoredActivePrompt = true;
}

function clearPromptState(): void {
	pendingPrompt = undefined;
	activePrompt = undefined;
	restoredActivePrompt = false;
}

export default function restoreCancelledPrompt(pi: ExtensionAPI) {
	pi.on("session_start", () => {
		clearPromptState();
	});

	pi.on("session_shutdown", () => {
		clearPromptState();
	});

	pi.on("input", (event) => {
		// Only restore prompts typed into the interactive editor.
		// Queued steering/follow-up messages are already restored by Pi itself.
		if (event.streamingBehavior !== undefined) {
			return { action: "continue" };
		}

		pendingPrompt = event.source === "interactive" ? event.text : null;
		return { action: "continue" };
	});

	pi.on("before_agent_start", () => {
		activePrompt = pendingPrompt ?? undefined;
		pendingPrompt = undefined;
		restoredActivePrompt = false;
	});

	pi.on("message_end", (event, ctx) => {
		if (isAssistantAbort(event.message)) {
			restoreActivePrompt(ctx);
		}
	});

	pi.on("agent_end", (event, ctx) => {
		if (event.messages.some(isAssistantAbort)) {
			restoreActivePrompt(ctx);
		} else {
			activePrompt = undefined;
			restoredActivePrompt = false;
		}
	});
}
