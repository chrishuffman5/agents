# State Management Patterns

Comparison of Context+useReducer, Zustand, Jotai, Redux Toolkit, and TanStack Query.

---

## Built-In: Context + useReducer

Best for: app-wide settings (theme, locale, auth), small-to-medium apps, zero dependencies.

```tsx
type AuthState = { user: User | null; isLoading: boolean };
type AuthAction =
  | { type: "LOGIN"; payload: User }
  | { type: "LOGOUT" }
  | { type: "LOADING" };

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case "LOADING": return { ...state, isLoading: true };
    case "LOGIN": return { user: action.payload, isLoading: false };
    case "LOGOUT": return { user: null, isLoading: false };
  }
}

const AuthContext = createContext<{
  state: AuthState;
  dispatch: React.Dispatch<AuthAction>;
} | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, {
    user: null, isLoading: false,
  });
  return <AuthContext value={{ state, dispatch }}>{children}</AuthContext>;
}

export function useAuth() {
  const ctx = use(AuthContext); // React 19: use() instead of useContext()
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
```

**Strengths:** Zero dependencies, built into React, familiar reducer pattern.

**Limitation:** All consumers re-render on any state change. Split into multiple contexts for granular subscriptions.

---

## Zustand

Best for: client-only global state with minimal boilerplate, medium complexity.

```tsx
import { create } from "zustand";

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  total: () => number;
}

const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) => set((state) => ({ items: [...state.items, item] })),
  removeItem: (id) =>
    set((state) => ({ items: state.items.filter((i) => i.id !== id) })),
  total: () => get().items.reduce((sum, item) => sum + item.price, 0),
}));

// Components subscribe to specific slices -- no unnecessary re-renders
function CartCount() {
  const count = useCartStore((state) => state.items.length);
  return <span>{count} items</span>;
}

function CartTotal() {
  const total = useCartStore((state) => state.total());
  return <span>${total.toFixed(2)}</span>;
}
```

**Strengths:** Tiny bundle (~1KB), no Provider needed, built-in selectors for granular subscriptions, middleware support (persist, devtools, immer).

**When to choose:** Client-side UI state shared across many components. Cart, UI toggles, wizard state.

---

## Jotai

Best for: fine-grained atomic state, derived state, avoiding context hell without a global store.

```tsx
import { atom, useAtom, useAtomValue } from "jotai";

// Base atoms
const userAtom = atom<User | null>(null);
const cartAtom = atom<CartItem[]>([]);

// Derived atoms (automatically re-compute when dependencies change)
const isLoggedInAtom = atom((get) => get(userAtom) !== null);
const cartTotalAtom = atom((get) =>
  get(cartAtom).reduce((sum, item) => sum + item.price, 0)
);

// Writable derived atom
const addToCartAtom = atom(null, (get, set, item: CartItem) => {
  set(cartAtom, [...get(cartAtom), item]);
});

function LoginStatus() {
  const isLoggedIn = useAtomValue(isLoggedInAtom); // read-only subscription
  return <span>{isLoggedIn ? "Logged in" : "Logged out"}</span>;
}

function UserMenu() {
  const [user, setUser] = useAtom(userAtom); // read + write
  // ...
}
```

**Strengths:** Bottom-up atomic model, automatic dependency tracking, derived atoms, works with Suspense and Server Components, tiny bundle.

**When to choose:** Many independent pieces of state with derived relationships. Avoids single monolithic store.

---

## Redux Toolkit

Best for: large teams, complex domain logic, time-travel debugging, existing Redux codebases.

```tsx
import { createSlice, configureStore, PayloadAction } from "@reduxjs/toolkit";

const counterSlice = createSlice({
  name: "counter",
  initialState: { value: 0 },
  reducers: {
    increment: (state) => { state.value += 1; },       // Immer-powered mutation
    decrement: (state) => { state.value -= 1; },
    setCount: (state, action: PayloadAction<number>) => {
      state.value = action.payload;
    },
  },
});

export const store = configureStore({
  reducer: { counter: counterSlice.reducer },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
export const { increment, decrement, setCount } = counterSlice.actions;
```

**Strengths:** Predictable state, Redux DevTools (time travel, action log), RTK Query for data fetching, strong TypeScript support, large ecosystem.

**When to choose:** Large applications with complex state transitions, teams that value strict unidirectional data flow, or existing Redux codebases.

---

## TanStack Query

Best for: server state (fetching, caching, invalidation, background refetch). Not a general state manager -- pairs with any of the above for client state.

```tsx
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ["user", userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });

  const queryClient = useQueryClient();
  const updateMutation = useMutation({
    mutationFn: (updates: Partial<User>) => updateUser(userId, updates),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["user", userId] });
    },
  });

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  return <div>{user?.name}</div>;
}
```

**Strengths:** Automatic caching and deduplication, background refetch, optimistic updates, pagination/infinite queries, Suspense integration, DevTools.

**When to choose:** Any application that fetches data from APIs. Pair with Zustand or Jotai for client-only UI state.

---

## Decision Matrix

| Scenario | Recommendation |
|---|---|
| Theme, locale, auth session | Context + useReducer |
| Client UI state across many components | Zustand |
| Atomic derived state, no global store | Jotai |
| Large team, complex domain logic | Redux Toolkit |
| Remote/server data fetching + caching | TanStack Query |
| Forms with async submit | useActionState + useOptimistic (React 19) |
| Form field state | Uncontrolled inputs + FormData (React 19) |
| Mixed server + client state | TanStack Query + Zustand or Jotai |

---

## Combining Libraries

A common production stack:
- **TanStack Query** for server state (API data, caching, mutations)
- **Zustand** or **Jotai** for client-only UI state (modals, wizard steps, preferences)
- **Context** for low-frequency global values (theme, locale)

Avoid duplicating server state in client stores. Let TanStack Query own remote data and use its cache as the source of truth.
