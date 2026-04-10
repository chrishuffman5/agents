# Angular Architecture Reference

Deep reference for Angular's core architectural concepts. Covers components, dependency injection, change detection, modules vs standalone, routing, template syntax, RxJS integration, build system, and forms.

---

## 1. Component Model

Angular components are the primary UI building block. Since v17, **standalone components are the default** -- NgModule wrappers are no longer required.

### Standalone Component (Default)

```typescript
import { Component, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-user-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './user-card.component.html',
  styleUrl: './user-card.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserCardComponent {
  name = input.required<string>();
  selected = output<string>();
}
```

### Key Decorators

- `@Component` -- declares a component: `selector`, `template`/`templateUrl`, `styles`/`styleUrl`, `standalone`, `imports`, `changeDetection`, `encapsulation`, `providers`
- `@Directive` -- attaches behavior to a DOM element (structural or attribute)
- `@Pipe` -- transforms values in templates; add `pure: false` for impure pipes
- `@Injectable` -- marks a class as injectable; use `providedIn: 'root'` for singleton services

### View Encapsulation

| Mode | Behavior |
|---|---|
| `Emulated` (default) | Angular scopes CSS via attribute selectors (no native Shadow DOM) |
| `ShadowDom` | Uses native Shadow DOM; CSS is truly isolated |
| `None` | Global CSS; styles bleed into child components |

### Change Detection Strategies

- **Default** -- checks the entire component tree on every async event (zone-driven)
- **OnPush** -- only checks when: `@Input` reference changes, an event originates in the component, `markForCheck()` is called, or an `async` pipe emits

### Lifecycle Hooks

| Hook | Timing |
|---|---|
| `ngOnChanges` | Before `ngOnInit` and whenever input bindings change |
| `ngOnInit` | Once, after first `ngOnChanges` |
| `ngDoCheck` | Every change detection run |
| `ngAfterContentInit` | After content projection |
| `ngAfterContentChecked` | After every check of projected content |
| `ngAfterViewInit` | After the component's view initializes |
| `ngAfterViewChecked` | After every check of the component's view |
| `ngOnDestroy` | Before the component is destroyed |

With signals, prefer `afterNextRender()` and `afterEveryRender()` over `ngAfterViewInit` for DOM-dependent initialization.

### Content Projection

```html
<!-- Component template -->
<div class="card">
  <ng-content select="[card-title]" />
  <ng-content />
  <ng-content select="[card-footer]" />
</div>

<!-- Usage -->
<app-card>
  <h2 card-title>Title</h2>
  <p>Body content</p>
  <button card-footer>OK</button>
</app-card>
```

---

## 2. Dependency Injection

DI is Angular's core infrastructure. The hierarchical injector tree provides fine-grained control over service scope and lifetime.

### Injector Hierarchy

```
Platform Injector          <-- platform-level services (very rare)
  +-- Root Injector        <-- services with providedIn: 'root'
        +-- Environment Injectors (lazy routes create child injectors)
              +-- Component Injectors  <-- providers: [] in @Component
                    +-- Element Injectors (directives)
```

### providedIn: 'root' -- Tree-Shakeable Singleton

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
}
```

Tree-shakeable: if `AuthService` is never injected, the bundler removes it.

### inject() Function (Preferred)

```typescript
@Component({ ... })
export class MyComponent {
  private authService = inject(AuthService);
  private router = inject(Router);
}
```

`inject()` works in constructors, field initializers, and factory functions. Preferred over constructor injection for readability and compatibility with standalone patterns.

### InjectionToken (Non-Class Values)

```typescript
export const API_BASE_URL = new InjectionToken<string>('API_BASE_URL', {
  providedIn: 'root',
  factory: () => 'https://api.example.com',
});

const baseUrl = inject(API_BASE_URL);
```

### Multi-Providers

```typescript
providers: [
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
  { provide: HTTP_INTERCEPTORS, useClass: LoggingInterceptor, multi: true },
]
```

### Factory Providers

```typescript
{
  provide: SomeService,
  useFactory: (config: AppConfig) => new SomeService(config.apiUrl),
  deps: [AppConfig],
}
```

### Component-Level Providers

```typescript
@Component({
  providers: [{ provide: LogService, useClass: VerboseLogService }]
})
```

Creates a new instance per component -- useful for component-scoped state.

---

## 3. Change Detection

### Zone.js Model (Default through v20)

Zone.js monkey-patches browser async APIs (`setTimeout`, `Promise`, `fetch`, `addEventListener`). After any async operation, Angular's `NgZone` triggers change detection from the root down.

**Flow:**
1. User clicks / timer fires / HTTP response arrives
2. Zone.js intercepts and notifies Angular
3. Angular calls `ApplicationRef.tick()` -- traverses all components top-down
4. Each component's view is checked; DOM is updated if bindings changed

**Drawback:** Every async event triggers a full tree check, including unrelated mouse moves and WebSocket messages.

### OnPush Strategy

Limits when a component is checked:
- A bound `@Input()` receives a new object reference
- An event handler fires within the component or its children
- An Observable/signal emits and the `async` pipe is used
- `ChangeDetectorRef.markForCheck()` is explicitly called

```typescript
export class MyComponent {
  private cdr = inject(ChangeDetectorRef);

  loadData() {
    this.dataService.fetch().subscribe(data => {
      this.data = data;
      this.cdr.markForCheck();
    });
  }
}
```

### Zoneless Model (v18+ experimental, v20 developer preview, v21 default)

Removes Zone.js entirely. Change detection is driven by signals and explicit scheduling.

```typescript
export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
  ]
};
```

**Zoneless triggers:**
- Signal read in template changes value
- `ChangeDetectorRef.markForCheck()` called
- `ApplicationRef.tick()` called manually
- `async` pipe emits

**Benefits:** Smaller bundles (~25-30KB saved), fewer unnecessary checks, cleaner stack traces, better SSR hydration performance.

---

## 4. Modules vs Standalone

### NgModule (Legacy Pattern)

```typescript
@NgModule({
  declarations: [UserListComponent, UserCardComponent],
  imports: [CommonModule, HttpClientModule, RouterModule.forChild(routes)],
  exports: [UserListComponent],
  providers: [UserService],
})
export class UserModule {}
```

### Standalone Components (Default since v17)

```typescript
@Component({
  standalone: true,
  imports: [RouterLink, AsyncPipe, UserCardComponent],
})
export class UserListComponent {}
```

Standalone components import what they need directly. In v19+, `standalone: true` is implicit for new generated code.

### Migration

```bash
ng generate @angular/core:standalone
```

Runs in three passes: migrate components, remove unnecessary NgModules, bootstrap as standalone.

### When NgModules Still Make Sense

- Third-party libraries that ship as NgModules
- Large existing codebases mid-migration
- Lazy-loaded feature bundles with shared module injectors (less common now)

---

## 5. Routing

### Standalone App Setup

```typescript
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withPreloading(PreloadAllModules), withViewTransitions()),
    provideHttpClient(withInterceptorsFromDi()),
  ]
};
```

### Route Configuration

```typescript
export const routes: Routes = [
  { path: '', redirectTo: 'home', pathMatch: 'full' },
  {
    path: 'home',
    loadComponent: () => import('./home/home.component').then(m => m.HomeComponent),
  },
  {
    path: 'admin',
    canActivate: [authGuard],
    loadChildren: () => import('./admin/admin.routes').then(m => m.ADMIN_ROUTES),
  },
  {
    path: 'user/:id',
    component: UserDetailComponent,
    resolve: { user: userResolver },
    canDeactivate: [unsavedChangesGuard],
  },
  { path: '**', component: NotFoundComponent },
];
```

### Functional Guards (Preferred)

```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  return authService.isLoggedIn() ? true : router.createUrlTree(['/login']);
};
```

### Lazy Loading

- `loadComponent` -- lazy load a single standalone component
- `loadChildren` -- lazy load a child route array (creates a child environment injector)

### Reading Route Parameters

```typescript
export class UserDetailComponent {
  private route = inject(ActivatedRoute);

  userId$ = this.route.paramMap.pipe(map(params => params.get('id')));
  userData = this.route.snapshot.data['user'];
}
```

---

## 6. Template Syntax

### Binding Forms

| Syntax | Direction | Example |
|---|---|---|
| `{{ expr }}` | Interpolation | `{{ user.name }}` |
| `[prop]="expr"` | Component to DOM | `[disabled]="isLoading"` |
| `(event)="handler()"` | DOM to Component | `(click)="save()"` |
| `[(ngModel)]="prop"` | Two-way | `[(ngModel)]="searchTerm"` |
| `[class.active]="bool"` | Class toggle | `[class.active]="isActive"` |
| `[style.color]="expr"` | Style binding | `[style.color]="'red'"` |

### Built-in Control Flow (v17+, Preferred)

```html
@if (user()) {
  <p>{{ user().name }}</p>
} @else if (loading()) {
  <app-spinner />
} @else {
  <p>No user found</p>
}

@for (item of items(); track item.id) {
  <li>{{ item.name }}</li>
} @empty {
  <li>No items</li>
}

@switch (status()) {
  @case ('active') { <span class="green">Active</span> }
  @case ('inactive') { <span class="red">Inactive</span> }
  @default { <span>Unknown</span> }
}
```

### Defer Blocks (v17+)

```html
@defer (on viewport) {
  <app-heavy-component />
} @placeholder {
  <div>Loading...</div>
} @loading (minimum 500ms) {
  <app-spinner />
}
```

Conditions: `on idle`, `on viewport`, `on interaction`, `on hover`, `on immediate`, `on timer(ms)`, `when condition`.

### Template Reference Variables

```html
<input #searchInput type="text" />
<button (click)="search(searchInput.value)">Search</button>
```

### ng-template, ng-container

```html
<ng-template #loadingTpl><app-spinner /></ng-template>

<ng-container *ngIf="user">
  <h2>{{ user.name }}</h2>
  <p>{{ user.email }}</p>
</ng-container>
```

---

## 7. RxJS Integration

Angular's reactive layer is built on RxJS. Observables appear throughout: HTTP, routing, forms, async communication.

### HttpClient

```typescript
@Injectable({ providedIn: 'root' })
export class UserService {
  private http = inject(HttpClient);

  getUsers(): Observable<User[]> {
    return this.http.get<User[]>('/api/users');
  }

  getUserById(id: string): Observable<User> {
    return this.http.get<User>(`/api/users/${id}`).pipe(
      catchError(err => {
        console.error(err);
        return throwError(() => new Error('User not found'));
      })
    );
  }
}
```

### Key Operators

| Operator | Use Case |
|---|---|
| `map` | Transform emitted values |
| `filter` | Discard values that don't match predicate |
| `switchMap` | Cancel previous inner observable (typeahead search) |
| `mergeMap` | Allow concurrent inner observables |
| `concatMap` | Queue inner observables in order |
| `catchError` | Handle errors, return fallback Observable |
| `tap` | Side effects without transforming (logging) |
| `debounceTime` | Throttle rapid emissions (input events) |
| `distinctUntilChanged` | Skip duplicate consecutive emissions |
| `combineLatest` | Combine latest values from multiple streams |
| `takeUntilDestroyed` | Auto-complete when component is destroyed |

### Automatic Cleanup

```typescript
export class SearchComponent {
  private destroyRef = inject(DestroyRef);

  results$ = this.searchControl.valueChanges.pipe(
    debounceTime(300),
    distinctUntilChanged(),
    switchMap(term => this.searchService.search(term)),
    takeUntilDestroyed(this.destroyRef),
  );
}
```

### async Pipe

```html
@if (users$ | async; as users) {
  @for (user of users; track user.id) {
    <app-user-card [user]="user" />
  }
}
```

Subscribes, triggers change detection, and unsubscribes automatically.

### toSignal / toObservable Interop

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

users = toSignal(this.userService.getUsers(), { initialValue: [] });
searchQuery$ = toObservable(this.searchSignal);
```

---

## 8. Build System

### esbuild + Vite (Default since v17)

Angular CLI switched from Webpack to esbuild, with Vite powering the dev server. Key benefits: dramatically faster builds, smaller output.

**Builder:** `@angular-devkit/build-angular:application` (esbuild, v19) / `@angular/build:application` (v21)
**Legacy builder:** `@angular-devkit/build-angular:browser` (Webpack) -- still available

### Angular CLI Commands

```bash
ng new my-app                            # scaffold new standalone app
ng serve                                 # dev server with HMR
ng build                                 # production build (esbuild)
ng build --configuration development     # dev build
ng test                                  # run unit tests
ng generate component path/to/comp       # generate component
ng generate service path/to/service      # generate service
ng generate guard path/to/guard          # generate functional guard
ng lint                                  # lint with ESLint
```

### Schematics

Code-generation transformations used by `ng generate` and `ng update`. Third-party libraries ship schematics for `ng add`.

```bash
ng add @angular/material        # runs material schematic
ng update @angular/core@21      # runs update schematics for migrations
```

---

## 9. Forms

### Template-Driven Forms

```typescript
import { FormsModule } from '@angular/forms';
@Component({ imports: [FormsModule], ... })
```

```html
<form #loginForm="ngForm" (ngSubmit)="onSubmit(loginForm)">
  <input name="email" [(ngModel)]="email" required email />
  <input name="password" [(ngModel)]="password" required minlength="8" />
  <button type="submit" [disabled]="loginForm.invalid">Login</button>
</form>
```

### Reactive Forms (Preferred for Complex Scenarios)

```typescript
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';

@Component({ imports: [ReactiveFormsModule], ... })
export class LoginComponent {
  private fb = inject(FormBuilder);

  form: FormGroup = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
    address: this.fb.group({
      street: ['', Validators.required],
      city: [''],
    }),
  });

  onSubmit() {
    if (this.form.valid) {
      console.log(this.form.value);
    }
  }
}
```

### Typed Forms (v14+)

```typescript
const emailControl = new FormControl<string>('', { nonNullable: true });
emailControl.value; // type: string (not string | null)
```

### Async Validators

```typescript
emailAvailability(): AsyncValidatorFn {
  return (control: AbstractControl): Observable<ValidationErrors | null> => {
    return this.authService.checkEmail(control.value).pipe(
      map(isTaken => isTaken ? { emailTaken: true } : null),
      catchError(() => of(null)),
    );
  };
}
```

### Signal Forms (Experimental, v21)

```typescript
import { formGroup, formField, Validators } from '@angular/forms/experimental';

form = formGroup({
  name: formField('', { validators: [Validators.required] }),
  email: formField('', { validators: [Validators.required, Validators.email] }),
});

// Validation state is a computed signal
nameError = computed(() =>
  this.form.fields.name.errors()?.['required'] ? 'Name is required' : null
);
```

---

## Essential Imports Cheat Sheet

```typescript
// Routing (standalone app)
import { provideRouter, RouterLink, RouterOutlet, Router, ActivatedRoute } from '@angular/router';

// HTTP
import { provideHttpClient, HttpClient } from '@angular/common/http';

// Forms
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { FormsModule } from '@angular/forms';

// Common directives and pipes
import { NgClass, NgStyle, AsyncPipe, DatePipe, CurrencyPipe } from '@angular/common';

// DI utilities
import { inject, Injectable, InjectionToken, signal, computed, effect } from '@angular/core';

// RxJS
import { Observable, Subject, BehaviorSubject, combineLatest, of, throwError } from 'rxjs';
import { map, filter, switchMap, catchError, tap, debounceTime } from 'rxjs/operators';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

// Testing
import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
```
