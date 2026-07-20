# Form Patterns

React 19 Actions, `useActionState`, `useOptimistic`, and `useFormStatus`.

---

## Actions Overview

Actions are async functions passed to `<form action={fn}>`. React manages pending state, error handling, and form reset automatically. Forms work without JavaScript (progressive enhancement) when used with framework Server Actions.

---

## useActionState

Manages form submission state: previous result, wrapped action, and pending flag.

```tsx
const [state, action, isPending] = useActionState(fn, initialState, permalink?);
```

- `fn(previousState, formData)` -- called on submit; receives prior state and `FormData`
- `initialState` -- starting value before first submission
- `permalink` -- optional URL for progressive enhancement fallback
- Replaces the deprecated `useFormState` from `react-dom`

### Basic Example

```tsx
import { useActionState } from "react";

type State = { message: string } | null;

async function submitForm(prev: State, data: FormData): Promise<State> {
  const result = await saveToServer(data.get("email") as string);
  if (!result.ok) return { message: result.error };
  return null;
}

function ContactForm() {
  const [state, action, isPending] = useActionState(submitForm, null);

  return (
    <form action={action}>
      <input name="email" type="email" required />
      <button disabled={isPending}>
        {isPending ? "Saving..." : "Save"}
      </button>
      {state?.message && <p role="alert">{state.message}</p>}
    </form>
  );
}
```

---

## useFormStatus

Reads the pending state of the nearest ancestor `<form>` without prop drilling. Must be called from a component rendered **inside** the form.

```tsx
import { useFormStatus } from "react-dom";

function SubmitButton() {
  const { pending, data, method, action } = useFormStatus();
  return (
    <button type="submit" disabled={pending} aria-busy={pending}>
      {pending ? "Submitting..." : "Submit"}
    </button>
  );
}

function MyForm() {
  return (
    <form action={someAction}>
      <input name="query" />
      <SubmitButton /> {/* Reads parent form's state */}
    </form>
  );
}
```

**Fields returned:**
- `pending` -- boolean, true while the form action executes
- `data` -- `FormData` of the current submission
- `method` -- HTTP method string (`"get"` or `"post"`)
- `action` -- reference to the action function or URL

---

## useOptimistic

Displays an optimistic value while an async operation is pending. Reverts to real state on completion or error.

```tsx
import { useOptimistic } from "react";

type Message = { id: string; text: string; sending?: boolean };

function MessageThread({ messages }: { messages: Message[] }) {
  const [optimisticMessages, addOptimistic] = useOptimistic(
    messages,
    (state: Message[], newText: string) => [
      ...state,
      { id: crypto.randomUUID(), text: newText, sending: true },
    ]
  );

  async function sendMessage(formData: FormData) {
    const text = formData.get("message") as string;
    addOptimistic(text);        // instant UI update
    await postMessage(text);    // actual API call
  }

  return (
    <>
      {optimisticMessages.map((m) => (
        <p key={m.id} style={{ opacity: m.sending ? 0.5 : 1 }}>{m.text}</p>
      ))}
      <form action={sendMessage}>
        <input name="message" />
        <button type="submit">Send</button>
      </form>
    </>
  );
}
```

---

## Complete Form Pattern

Combining all three hooks for a production-ready form:

```tsx
// actions/contact.ts (Server Action or async function)
export async function submitContact(
  prev: FormState,
  data: FormData
): Promise<FormState> {
  const email = data.get("email") as string;
  const message = data.get("message") as string;

  if (!email || !message) return { error: "All fields are required." };

  const result = await sendEmail({ email, message });
  if (!result.ok) return { error: result.error };
  return { success: true };
}
```

```tsx
// components/ContactForm.tsx ("use client")
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { submitContact, type FormState } from "@/actions/contact";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} aria-busy={pending}>
      {pending ? "Sending..." : "Send Message"}
    </button>
  );
}

export function ContactForm() {
  const [state, action, isPending] = useActionState<FormState, FormData>(
    submitContact, {}
  );

  if (state.success) {
    return <p role="status">Message sent successfully!</p>;
  }

  return (
    <form action={action} noValidate>
      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" required
        aria-invalid={!!state.error} disabled={isPending} />

      <label htmlFor="message">Message</label>
      <textarea id="message" name="message" required disabled={isPending} />

      {state.error && <p role="alert" aria-live="polite">{state.error}</p>}
      <SubmitButton />
    </form>
  );
}
```

---

## Multi-Action Forms

Use `<button formAction={fn}>` to override the parent form's action per button:

```tsx
<form action={saveAction}>
  <input name="title" />
  <button type="submit">Save Draft</button>
  <button type="submit" formAction={publishAction}>Publish</button>
</form>
```

---

## Key Guidelines

- Prefer uncontrolled inputs with `FormData` for Actions (React 19 default pattern)
- Use `useActionState` instead of manual `isPending`/`error` state
- Use `useFormStatus` in child components instead of prop-drilling pending state
- Use `useOptimistic` for instant UI feedback on mutations
- Always validate inputs server-side in Server Actions (they are public endpoints)
- Forms with `action={serverAction}` work without JavaScript (progressive enhancement)
