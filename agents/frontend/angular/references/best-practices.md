# Angular Best Practices Reference

Design patterns, state management, performance optimization, and testing strategies for Angular applications.

---

## 1. Component Design

### Smart vs Presentational (Container/Presenter Pattern)

- **Smart components** (containers): inject services, manage state, orchestrate data flow, connected to router
- **Presentational components**: receive data via inputs, emit events via outputs, no service injection, highly reusable

```typescript
// Smart (container)
@Component({ ... })
export class UserListContainerComponent {
  private userService = inject(UserService);
  users = toSignal(this.userService.getUsers(), { initialValue: [] });
}

// Presentational
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListComponent {
  users = input<User[]>([]);
  userSelected = output<User>();
}
```

### Single Responsibility

- One component = one concern
- If a template exceeds ~100 lines, consider decomposition
- Extract repeated patterns into shared components

### Content Projection for Flexibility

Use `ng-content` slots to build generic layout components (cards, dialogs, panels) without coupling to specific content.

### Always Use OnPush

Set `ChangeDetectionStrategy.OnPush` by default. Configure ng generate to apply OnPush automatically:

```json
"schematics": {
  "@schematics/angular:component": {
    "changeDetection": "OnPush"
  }
}
```

### Prefer inject() Over Constructor Injection

```typescript
// Preferred
export class MyComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
}

// Legacy (still works but verbose)
export class MyComponent {
  constructor(private auth: AuthService, private router: Router) {}
}
```

### Prefer Signal-Based APIs

For new code, prefer `input()` over `@Input()`, `output()` over `@Output()`, `viewChild()` over `@ViewChild()`, and `model()` over the `@Input()` + `@Output() Change` pattern.

---

## 2. State Management

### Decision Matrix

| Scope | Solution |
|---|---|
| Single component | Local signals or class fields |
| Shared between sibling components | Shared service with signals |
| Feature-level state | NgRx ComponentStore or NgRx Signal Store |
| App-wide complex state | NgRx Store (Redux pattern) |

### Service with Signals (Recommended for Most Cases)

```typescript
@Injectable({ providedIn: 'root' })
export class CartService {
  private items = signal<CartItem[]>([]);

  readonly cartItems = this.items.asReadonly();
  readonly itemCount = computed(() => this.items().length);
  readonly total = computed(() => this.items().reduce((sum, i) => sum + i.price, 0));

  addItem(item: CartItem) {
    this.items.update(items => [...items, item]);
  }

  removeItem(id: string) {
    this.items.update(items => items.filter(i => i.id !== id));
  }
}
```

### Service with BehaviorSubject (RxJS Pattern)

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private userSubject = new BehaviorSubject<User | null>(null);
  user$ = this.userSubject.asObservable();

  login(credentials: Credentials): Observable<User> {
    return this.http.post<User>('/api/login', credentials).pipe(
      tap(user => this.userSubject.next(user)),
    );
  }
}
```

### NgRx Signal Store (v18+)

Signal-native alternative to classic NgRx Store:

```typescript
import { signalStore, withState, withComputed, withMethods } from '@ngrx/signals';

export const CartStore = signalStore(
  { providedIn: 'root' },
  withState({ items: [] as CartItem[] }),
  withComputed(({ items }) => ({
    total: computed(() => items().reduce((s, i) => s + i.price, 0))
  })),
  withMethods((store) => ({
    addItem: (item: CartItem) => patchState(store, { items: [...store.items(), item] })
  }))
);
```

### NgRx Store (Full Redux -- Large Complex Apps)

Appropriate when: multiple developers, complex state interactions, time-travel debugging needed, strict unidirectional data flow required.

---

## 3. Performance

### OnPush Everywhere

The single highest-impact optimization. Reduces the number of components checked per change detection cycle dramatically.

### track in @for (Mandatory)

```html
@for (item of items(); track item.id) {
  <li>{{ item.name }}</li>
}
```

`track` is required syntax in `@for`. Always track by a stable unique identifier.

### Lazy Loading Routes

Every feature route should be lazy-loaded to keep the initial bundle small:

```typescript
{ path: 'feature', loadComponent: () => import('./feature.component').then(m => m.FeatureComponent) }
```

### Preloading Strategies

```typescript
provideRouter(routes, withPreloading(PreloadAllModules))
```

### Defer Blocks

```html
@defer (on viewport) {
  <app-heavy-component />
} @placeholder {
  <div>Loading...</div>
}
```

### Bundle Analysis

```bash
ng build --stats-json
npx source-map-explorer dist/my-app/browser/*.js
```

### Tree-Shaking

- Use `providedIn: 'root'` for services
- Import only specific RxJS operators
- Import specific Angular Material components, not barrel modules

### Image Optimization

```html
<img ngSrc="hero.jpg" width="800" height="600" priority />
```

`NgOptimizedImage` adds `fetchpriority`, lazy loading, and size attributes automatically.

### runOutsideAngular (Zone.js Apps)

```typescript
this.ngZone.runOutsideAngular(() => {
  this.mapElement.addEventListener('mousemove', this.onMouseMove.bind(this));
});
```

Prevent high-frequency events from triggering unnecessary change detection.

---

## 4. Testing

### TestBed -- Component Testing

```typescript
describe('UserCardComponent', () => {
  let fixture: ComponentFixture<UserCardComponent>;
  let component: UserCardComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserCardComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(UserCardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should display user name', () => {
    const el = fixture.nativeElement.querySelector('h2');
    expect(el.textContent).toContain('Alice');
  });
});
```

### Testing with HttpClient

```typescript
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

beforeEach(() => {
  TestBed.configureTestingModule({
    providers: [provideHttpClient(), provideHttpClientTesting()],
  });
  httpTesting = TestBed.inject(HttpTestingController);
});

afterEach(() => httpTesting.verify());

it('should fetch users', () => {
  service.getUsers().subscribe(users => expect(users.length).toBe(2));
  const req = httpTesting.expectOne('/api/users');
  req.flush([{ id: 1 }, { id: 2 }]);
});
```

### Testing with Router

```typescript
TestBed.configureTestingModule({
  providers: [provideRouter([])],
});
```

### Testing Zoneless Components

```typescript
TestBed.configureTestingModule({
  providers: [provideZonelessChangeDetection()]
});

fixture.detectChanges();
await fixture.whenStable();
```

### Component Harnesses (@angular/cdk/testing)

```typescript
import { MatButtonHarness } from '@angular/material/button/testing';
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';

let loader = TestbedHarnessEnvironment.loader(fixture);
const button = await loader.getHarness(MatButtonHarness.with({ text: 'Submit' }));
await button.click();
```

Harnesses provide a stable API decoupled from internal DOM structure.

### Vitest (v21 Default)

```typescript
import { vi } from 'vitest';

it('debounces search input', () => {
  vi.useFakeTimers();
  const fixture = TestBed.createComponent(SearchComponent);
  component.onInput('angular');
  vi.advanceTimersByTime(300);
  expect(component.searchTerm()).toBe('angular');
  vi.useRealTimers();
});
```

Vitest features: fake timers, import mocking, snapshot testing, parallel execution, no browser launch required.
