// Program.cs -- Blazor Web App (.NET 8/9/10)
// Supports Static SSR + Interactive Server + Interactive WebAssembly (Auto mode)

var builder = WebApplication.CreateBuilder(args);

// -- Core Razor / Blazor setup -------------------------------------------------
builder.Services.AddRazorComponents()                // Enables Razor component rendering
    .AddInteractiveServerComponents()                // Enables @rendermode InteractiveServer
    .AddInteractiveWebAssemblyComponents();          // Enables @rendermode InteractiveWebAssembly
    // Omit either line to disable that render mode.
    // Server-only: .AddInteractiveServerComponents() alone
    // WASM-only: .AddInteractiveWebAssemblyComponents() alone

// -- Authentication ------------------------------------------------------------
builder.Services.AddCascadingAuthenticationState();  // Provides AuthenticationState cascade
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Cookies";
    options.DefaultChallengeScheme = "oidc";
})
    .AddCookie()
    .AddOpenIdConnect("oidc", options =>
    {
        // Configure OIDC provider (Azure AD, Auth0, Keycloak, etc.)
    });

// -- Auth state serialization (.NET 9+) ----------------------------------------
// Automates sharing ClaimsPrincipal across prerender/WASM boundary
// builder.Services.AddRazorComponents()
//     .AddInteractiveWebAssemblyComponents()
//     .AddAuthenticationStateSerialization();

// -- Application services ------------------------------------------------------
builder.Services.AddScoped<IWeatherService, WeatherService>();  // per-circuit (Server)
builder.Services.AddHttpClient<ApiClient>(client =>             // Typed HttpClient for WASM
    client.BaseAddress = new Uri(builder.Configuration["ApiBase"]!));

// -- SignalR tuning (Interactive Server) ----------------------------------------
builder.Services.Configure<HubOptions>(options =>
{
    options.MaximumReceiveMessageSize = 32 * 1024;   // 32 KB max message
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
});

// -- Circuit persistence (.NET 10) ----------------------------------------------
// Serialize/resume circuit state after disconnect
// builder.Services.AddRazorComponents()
//     .AddInteractiveServerComponents(options =>
//     {
//         options.CircuitPersistence.Enabled = true;
//         options.CircuitPersistence.StorageProvider = CircuitPersistenceStorage.DistributedCache;
//     });

// -- Azure SignalR backplane (multi-server deployments) -------------------------
// builder.Services.AddSignalR().AddAzureSignalR(connectionString);

var app = builder.Build();

// -- Middleware pipeline -------------------------------------------------------
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();

// .NET 8: app.UseStaticFiles();
// .NET 9+: prefer MapStaticAssets for fingerprinted URLs and aggressive caching
app.MapStaticAssets();         // .NET 9+; falls back to UseStaticFiles on .NET 8

app.UseAntiforgery();          // Required for Enhanced Form Handling (POST forms)
app.UseAuthentication();
app.UseAuthorization();

// -- Blazor endpoint mapping ---------------------------------------------------
app.MapRazorComponents<App>()  // Root component (App.razor)
    .AddInteractiveServerRenderMode()            // Wire up SignalR hub
    .AddInteractiveWebAssemblyRenderMode()       // Wire up WASM loading
    .AddAdditionalAssemblies(                    // Include components from class libraries
        typeof(SharedLib.Components._Imports).Assembly);

// -- Additional API endpoints --------------------------------------------------
app.MapGet("/api/weather", async (IWeatherService svc) =>
    await svc.GetForecastAsync());

app.Run();
