# Remix / React Router v7 Form Patterns

Patterns for actions, Zod validation, and progressive enhancement.

---

## Basic Form with Action

```tsx
import { Form, useActionData, useNavigation, redirect, data } from "react-router";
import type { ActionFunctionArgs } from "react-router";

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const email = String(formData.get("email"));

  if (!email.includes("@")) {
    return data({ error: "Invalid email" }, { status: 422 });
  }

  await subscribe(email);
  return redirect("/thank-you");
}

export default function SubscribePage() {
  const actionData = useActionData<typeof action>();
  const { state } = useNavigation();

  return (
    <Form method="post">
      <input name="email" type="email" />
      {actionData?.error && <p className="error">{actionData.error}</p>}
      <button type="submit" disabled={state === "submitting"}>
        {state === "submitting" ? "Subscribing..." : "Subscribe"}
      </button>
    </Form>
  );
}
```

Without JavaScript: plain HTML form POST. With JavaScript: fetch-based, no full reload.

---

## Zod Validation Pattern

```typescript
import { z } from "zod";
import { data, redirect } from "react-router";

const ProductSchema = z.object({
  name: z.string().min(1, "Name is required"),
  price: z.coerce.number().positive("Must be positive"),
  category: z.enum(["electronics", "clothing", "food"]),
});

export async function action({ request }: ActionFunctionArgs) {
  const result = ProductSchema.safeParse(
    Object.fromEntries(await request.formData())
  );

  if (!result.success) {
    return data(
      { errors: result.error.flatten().fieldErrors },
      { status: 422 }
    );
  }

  const product = await db.product.create({ data: result.data });
  return redirect(`/products/${product.id}`);
}
```

Display errors:

```tsx
const actionData = useActionData<typeof action>();

<input name="name" />
{actionData?.errors?.name && <p>{actionData.errors.name[0]}</p>}
```

---

## Multiple Actions per Route

Use the `intent` pattern to distinguish between different form actions:

```tsx
<Form method="post">
  <input name="title" />
  <button name="intent" value="save">Save Draft</button>
  <button name="intent" value="publish">Publish</button>
</Form>
```

```typescript
export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const intent = formData.get("intent");

  if (intent === "publish") {
    await publishPost(formData);
    return redirect("/posts");
  }

  await saveDraft(formData);
  return redirect("/drafts");
}
```

---

## useFetcher for Inline Mutations

When the mutation should not trigger navigation:

```tsx
function DeleteButton({ itemId }: { itemId: string }) {
  const fetcher = useFetcher();
  const isDeleting = fetcher.state !== "idle";

  return (
    <fetcher.Form method="delete" action={`/items/${itemId}`}>
      <button disabled={isDeleting}>
        {isDeleting ? "Deleting..." : "Delete"}
      </button>
    </fetcher.Form>
  );
}
```

---

## Progressive Enhancement Checklist

1. **Use `<Form>` instead of `<form>`** -- React Router's `<Form>` enhances with AJAX when JS is available.
2. **Always include `name` on inputs** -- FormData requires it.
3. **Always redirect after success** -- PRG pattern prevents double submission.
4. **Show pending state** -- Use `useNavigation().state` for full-page forms, `fetcher.state` for inline.
5. **Return 422 for validation errors** -- Return errors with `data()`, not redirect.
6. **Test without JavaScript** -- Disable JS in DevTools and verify the form still works.
