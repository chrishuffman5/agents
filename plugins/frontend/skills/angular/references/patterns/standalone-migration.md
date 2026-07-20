# NgModules to Standalone Migration Guide

Step-by-step guide for migrating Angular applications from NgModule-based architecture to standalone components.

---

## Overview

Standalone components (default since Angular 17) import dependencies directly without NgModule wrappers. Migration can be done incrementally -- standalone and NgModule-based components coexist.

---

## Step 1: Run the Automated Schematic

Angular provides a three-pass migration schematic:

```bash
ng generate @angular/core:standalone
```

The schematic runs in three phases:
1. **Convert components**: adds `standalone: true` and moves `imports` from NgModule to component
2. **Remove unnecessary NgModules**: deletes modules that only served as import containers
3. **Bootstrap as standalone**: converts `AppModule` bootstrap to `bootstrapApplication()`

Run each phase separately and verify between them.

---

## Step 2: Update Component Declarations

**Before (NgModule):**

```typescript
@NgModule({
  declarations: [UserListComponent, UserCardComponent],
  imports: [CommonModule, ReactiveFormsModule],
  exports: [UserListComponent],
})
export class UserModule {}
```

**After (Standalone):**

```typescript
@Component({
  standalone: true,
  imports: [ReactiveFormsModule, UserCardComponent],
  // ...
})
export class UserListComponent {}

@Component({
  standalone: true,
  imports: [CommonModule],
  // ...
})
export class UserCardComponent {}
```

---

## Step 3: Update App Bootstrap

**Before (NgModule bootstrap):**

```typescript
// main.ts
platformBrowserDynamic().bootstrapModule(AppModule);

// app.module.ts
@NgModule({
  declarations: [AppComponent],
  imports: [BrowserModule, RouterModule.forRoot(routes), HttpClientModule],
  bootstrap: [AppComponent],
})
export class AppModule {}
```

**After (Standalone bootstrap):**

```typescript
// main.ts
bootstrapApplication(AppComponent, appConfig);

// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient(),
    provideAnimationsAsync(),
  ]
};
```

---

## Step 4: Convert Lazy-Loaded Feature Modules

**Before:**

```typescript
{ path: 'admin', loadChildren: () => import('./admin/admin.module').then(m => m.AdminModule) }
```

**After:**

```typescript
{ path: 'admin', loadChildren: () => import('./admin/admin.routes').then(m => m.ADMIN_ROUTES) }
// or for a single component:
{ path: 'admin', loadComponent: () => import('./admin/admin.component').then(m => m.AdminComponent) }
```

---

## Step 5: Replace Module-Level Providers

**Before:**

```typescript
@NgModule({
  providers: [{ provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true }],
})
export class CoreModule {}
```

**After:**

```typescript
// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptorsFromDi()),
    // or use functional interceptors:
    provideHttpClient(withInterceptors([authInterceptor])),
  ]
};
```

---

## Step 6: Handle Third-Party NgModules

Some libraries still ship as NgModules. Import them directly in standalone components:

```typescript
@Component({
  standalone: true,
  imports: [MatButtonModule, MatCardModule], // Angular Material modules
})
export class DashboardComponent {}
```

---

## Common Issues During Migration

| Issue | Solution |
|---|---|
| Circular imports between components | Restructure to break the cycle, use lazy imports |
| Missing imports after removing NgModule | Add required directives/pipes to each component's `imports` |
| Provider scope changes | Move providers to `app.config.ts` or component-level `providers` |
| `forRoot`/`forChild` patterns | Replace with `provide*` functions (e.g., `provideRouter`) |

---

## Verification Checklist

- [ ] `ng build` succeeds without errors
- [ ] `ng test` passes all tests
- [ ] Lazy-loaded routes produce separate chunk files
- [ ] No remaining `@NgModule` declarations (except third-party)
- [ ] `AppModule` replaced by `app.config.ts` + `bootstrapApplication()`
