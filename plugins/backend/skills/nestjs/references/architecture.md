# NestJS Architecture Reference

## Module System

### @Module Decorator

NestJS organizes code into cohesive modules. The root `AppModule` bootstraps everything; feature modules encapsulate domain logic.

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
```

- `imports` -- other modules whose exports this module needs
- `providers` -- DI-registered services, guards, interceptors, etc.
- `controllers` -- route handlers scoped to this module
- `exports` -- subset of providers re-exported for consumers

### Dynamic Modules

Dynamic modules accept configuration at import time. The canonical pattern exposes `register` (sync) and `registerAsync` (factory with DI):

```typescript
@Module({})
export class DatabaseModule {
  static register(options: DatabaseOptions): DynamicModule {
    return {
      module: DatabaseModule,
      providers: [
        { provide: DATABASE_OPTIONS, useValue: options },
        DatabaseService,
      ],
      exports: [DatabaseService],
    };
  }

  static registerAsync(options: {
    useFactory: (...args: any[]) => DatabaseOptions | Promise<DatabaseOptions>;
    inject?: any[];
    imports?: any[];
  }): DynamicModule {
    return {
      module: DatabaseModule,
      imports: options.imports ?? [],
      providers: [
        { provide: DATABASE_OPTIONS, useFactory: options.useFactory, inject: options.inject ?? [] },
        DatabaseService,
      ],
      exports: [DatabaseService],
    };
  }
}

// Usage
DatabaseModule.registerAsync({
  imports: [ConfigModule],
  useFactory: (config: ConfigService) => ({
    host: config.get('DB_HOST'),
    port: config.get<number>('DB_PORT'),
  }),
  inject: [ConfigService],
});
```

### Global Modules

Decorate with `@Global()` to make exports available everywhere without explicit import. Use sparingly -- appropriate for logging, config, event bus.

```typescript
@Global()
@Module({
  providers: [LoggerService],
  exports: [LoggerService],
})
export class LoggerModule {}
```

### Lazy Loading Modules

Use `LazyModuleLoader` for on-demand module loading in serverless or CLI contexts:

```typescript
@Injectable()
export class AppService {
  constructor(private readonly lazyModuleLoader: LazyModuleLoader) {}

  async doHeavyWork() {
    const { HeavyModule } = await import('./heavy/heavy.module');
    const moduleRef = await this.lazyModuleLoader.load(() => HeavyModule);
    const service = moduleRef.get(HeavyService);
    return service.process();
  }
}
```

Lazy-loaded modules cannot register controllers; they are provider-only.

---

## DI Container

### Provider Types

**Standard (class):**
```typescript
@Injectable()
export class UsersService { ... }
```

**Value provider:**
```typescript
{ provide: UsersService, useValue: mockUsersService }
```

**Class provider (aliasing/swapping):**
```typescript
{ provide: UsersService, useClass: MockUsersService }
```

**Factory provider:**
```typescript
{
  provide: 'ASYNC_CONNECTION',
  useFactory: async (config: ConfigService): Promise<Connection> => {
    return await createConnection(config.get('DB_URL'));
  },
  inject: [ConfigService],
}
```

**Existing provider (alias):**
```typescript
{ provide: 'AliasService', useExisting: RealService }
```

### Injection Scopes

```typescript
@Injectable({ scope: Scope.DEFAULT })   // singleton (default)
@Injectable({ scope: Scope.REQUEST })   // new instance per HTTP request
@Injectable({ scope: Scope.TRANSIENT }) // new instance per injection point
```

**Scope propagation:** If a singleton depends on a request-scoped service, the singleton becomes request-scoped. Design carefully.

Request-scoped providers can inject the raw `REQUEST` object:

```typescript
@Injectable({ scope: Scope.REQUEST })
export class AuditService {
  constructor(@Inject(REQUEST) private readonly request: Request) {}
}
```

### Constructor vs Property Injection

```typescript
// Constructor (standard, preferred)
@Injectable()
export class OrdersService {
  constructor(
    private readonly usersService: UsersService,
    @Inject('CONFIG') private readonly config: AppConfig,
  ) {}
}

// Property (for base classes where constructor injection is impractical)
@Injectable()
export class BaseService {
  @Inject(LoggerService)
  protected readonly logger: LoggerService;
}
```

### Circular Dependencies

Circular deps cause Nest to fail at startup. Resolve with `forwardRef`:

```typescript
@Injectable()
export class AService {
  constructor(@Inject(forwardRef(() => BService)) private b: BService) {}
}

@Module({
  imports: [forwardRef(() => BModule)],
  providers: [AService],
  exports: [AService],
})
export class AModule {}
```

**Prefer refactoring** circular deps away (extract shared service or use events) rather than relying on `forwardRef`.

### ModuleRef (Dynamic Resolution)

```typescript
@Injectable()
export class StrategyFactory {
  constructor(private moduleRef: ModuleRef) {}

  getStrategy(name: string): PaymentStrategy {
    return this.moduleRef.get<PaymentStrategy>(`${name}Strategy`, { strict: false });
  }
}
```

---

## Request Lifecycle (Detailed)

```
Incoming Request
  -> Global Middleware
  -> Module Middleware
  -> Global Guards
  -> Controller Guards
  -> Route Guards
  -> Global Interceptors (pre-handler)
  -> Controller Interceptors (pre-handler)
  -> Route Interceptors (pre-handler)
  -> Global Pipes
  -> Controller Pipes
  -> Route Pipes
  -> Parameter Pipes
  -> Route Handler
  -> Route Interceptors (post-handler)
  -> Controller Interceptors (post-handler)
  -> Global Interceptors (post-handler)
  -> Exception Filters (on error: route -> controller -> global)
  -> Response
```

Exception filters run in **reverse scope order** on error -- route-level first, then controller, then global.

---

## Middleware

### Class-based Middleware

```typescript
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
    next();
  }
}

// Apply in module
export class UsersModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(LoggerMiddleware)
      .forRoutes({ path: 'users', method: RequestMethod.GET });
    // Or apply to entire controller
    consumer.apply(AuthMiddleware).forRoutes(UsersController);
  }
}
```

### Functional Middleware

```typescript
export function correlationIdMiddleware(req: Request, res: Response, next: NextFunction) {
  req.headers['x-correlation-id'] ??= crypto.randomUUID();
  next();
}
```

### Global Middleware

```typescript
const app = await NestFactory.create(AppModule);
app.use(correlationIdMiddleware);
```

---

## Guards

Guards implement `CanActivate` and return `boolean | Promise<boolean> | Observable<boolean>`.

### Basic Auth Guard

```typescript
@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    return Boolean(request.user);
  }
}
```

### Role-Based Guard with Metadata

```typescript
// Decorator
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// Guard
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(), context.getClass(),
    ]);
    if (!requiredRoles) return true;
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some(role => user?.roles?.includes(role));
  }
}

// Usage
@Controller('admin')
@Roles('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {}
```

### JWT Guard (Passport)

```typescript
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest(err: any, user: any) {
    if (err || !user) throw err ?? new UnauthorizedException();
    return user;
  }
}

// Global guard via DI
{ provide: APP_GUARD, useClass: JwtAuthGuard }
```

---

## Interceptors

Interceptors wrap around request/response using RxJS.

```typescript
// Logging
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    const req = context.switchToHttp().getRequest();
    return next.handle().pipe(
      tap(() => console.log(`${req.method} ${req.url} -- ${Date.now() - start}ms`)),
    );
  }
}

// Response transformation
@Injectable()
export class TransformInterceptor<T> implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<{ data: T; timestamp: string }> {
    return next.handle().pipe(
      map(data => ({ data, timestamp: new Date().toISOString() })),
    );
  }
}

// Timeout
@Injectable()
export class TimeoutInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      timeout(5000),
      catchError(err => {
        if (err.name === 'TimeoutError') throw new RequestTimeoutException();
        throw err;
      }),
    );
  }
}
```

Apply via decorator or globally:
```typescript
@UseInterceptors(LoggingInterceptor)
@Controller('users')
export class UsersController {}

// Global
{ provide: APP_INTERCEPTOR, useClass: LoggingInterceptor }
```

---

## Pipes

### Built-in Pipes

```typescript
@Get(':id')
findOne(@Param('id', ParseUUIDPipe) id: string) {}

@Get()
filter(@Query('active', new DefaultValuePipe(true), ParseBoolPipe) active: boolean) {}
```

Available: `ParseIntPipe`, `ParseUUIDPipe`, `ParseBoolPipe`, `ParseArrayPipe`, `ParseEnumPipe`, `DefaultValuePipe`, `ValidationPipe`.

### ValidationPipe with class-validator

```typescript
// DTO
export class CreateUserDto {
  @IsEmail() email: string;
  @IsString() @MinLength(8) password: string;
  @IsOptional() @IsEnum(UserRole) role?: UserRole;
  @IsOptional() @IsString() @Transform(({ value }) => value?.trim()) name?: string;
}

// Global setup
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: true },
  exceptionFactory: errors => new BadRequestException(errors),
}));
```

### Custom Pipe

```typescript
@Injectable()
export class ParsePositiveIntPipe implements PipeTransform<string, number> {
  transform(value: string, metadata: ArgumentMetadata): number {
    const val = parseInt(value, 10);
    if (isNaN(val) || val <= 0) {
      throw new BadRequestException(`${metadata.data} must be a positive integer`);
    }
    return val;
  }
}
```

---

## Exception Filters

### Built-in HTTP Exceptions

```typescript
throw new BadRequestException('Invalid input');
throw new UnauthorizedException('Token expired');
throw new ForbiddenException('Insufficient permissions');
throw new NotFoundException(`User ${id} not found`);
throw new ConflictException('Email already registered');
throw new InternalServerErrorException();
```

### Custom Exception

```typescript
export class BusinessException extends HttpException {
  constructor(message: string, public readonly code: string) {
    super({ message, code, statusCode: HttpStatus.UNPROCESSABLE_ENTITY }, HttpStatus.UNPROCESSABLE_ENTITY);
  }
}
```

### Global Exception Filter

```typescript
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status = exception instanceof HttpException
      ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const message = exception instanceof HttpException
      ? exception.getResponse() : 'Internal server error';

    if (status >= 500) this.logger.error(exception);

    response.status(status).json({
      success: false,
      error: { code: typeof message === 'string' ? message : (message as any).code ?? 'ERROR', message },
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}

// Register globally
app.useGlobalFilters(new AllExceptionsFilter());
// Or via DI: { provide: APP_FILTER, useClass: AllExceptionsFilter }
```

---

## GraphQL Integration

### Code-First Setup

```typescript
@Module({
  imports: [
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
      sortSchema: true,
      playground: true,
      subscriptions: { 'graphql-ws': true },
    }),
  ],
})
export class AppModule {}
```

### Object Types and Resolvers

```typescript
@ObjectType()
export class User {
  @Field(() => ID) id: string;
  @Field() email: string;
  @Field({ nullable: true }) name?: string;
}

@Resolver(() => User)
export class UsersResolver {
  @Query(() => [User]) users() { return this.usersService.findAll(); }
  @Query(() => User, { nullable: true })
  user(@Args('id', { type: () => ID }) id: string) { return this.usersService.findOne(id); }
  @Mutation(() => User)
  createUser(@Args('input') input: CreateUserInput) { return this.usersService.create(input); }
  @Subscription(() => User)
  userCreated() { return pubSub.asyncIterableIterator('userCreated'); }
}
```

### Schema-First

```typescript
GraphQLModule.forRoot<ApolloDriverConfig>({
  driver: ApolloDriver,
  typePaths: ['**/*.graphql'],
  definitions: { path: join(process.cwd(), 'src/graphql.ts') },
});
```

---

## WebSockets

```typescript
@WebSocketGateway({ namespace: '/chat', cors: { origin: '*' } })
export class ChatGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  afterInit(server: Server) { console.log('WebSocket initialized'); }
  handleConnection(client: Socket) { console.log(`Connected: ${client.id}`); }
  handleDisconnect(client: Socket) { console.log(`Disconnected: ${client.id}`); }

  @SubscribeMessage('joinRoom')
  handleJoinRoom(@MessageBody() room: string, @ConnectedSocket() client: Socket) {
    client.join(room);
    return { event: 'joinedRoom', data: room };
  }

  @SubscribeMessage('sendMessage')
  handleMessage(@MessageBody() payload: { room: string; message: string }, @ConnectedSocket() client: Socket) {
    this.server.to(payload.room).emit('message', { from: client.id, message: payload.message });
  }
}
```

Guards, interceptors, and pipes work with `@WebSocketGateway`.

---

## Microservices

### Transport Layers

```typescript
// TCP
{ transport: Transport.TCP, options: { host: 'localhost', port: 3001 } }

// Redis
{ transport: Transport.REDIS, options: { host: 'localhost', port: 6379 } }

// RabbitMQ
{ transport: Transport.RMQ, options: { urls: ['amqp://localhost:5672'], queue: 'main_queue' } }

// Kafka
{ transport: Transport.KAFKA, options: { client: { brokers: ['localhost:9092'] }, consumer: { groupId: 'my-group' } } }

// gRPC
{ transport: Transport.GRPC, options: { package: 'users', protoPath: 'users.proto', url: 'localhost:5000' } }

// NATS
{ transport: Transport.NATS, options: { servers: ['nats://localhost:4222'] } }
```

### Message and Event Patterns

```typescript
// Request/response
@MessagePattern('add')
accumulate(@Payload() data: { a: number; b: number }): number {
  return data.a + data.b;
}

// Fire and forget
@EventPattern('user.created')
handleUserCreated(@Payload() user: any) { ... }
```

### Client

```typescript
@Injectable()
export class AppService {
  constructor(@Inject('MATH_SERVICE') private mathClient: ClientProxy) {}

  async add(a: number, b: number): Promise<number> {
    return firstValueFrom(this.mathClient.send<number>('add', { a, b }));
  }

  fireAndForget(event: string, data: any) {
    this.mathClient.emit(event, data);
  }
}
```

---

## CQRS

```typescript
// Command
export class CreateOrderCommand implements ICommand {
  constructor(public readonly userId: string, public readonly items: OrderItem[]) {}
}

@CommandHandler(CreateOrderCommand)
export class CreateOrderHandler implements ICommandHandler<CreateOrderCommand> {
  async execute(command: CreateOrderCommand): Promise<Order> {
    const order = await this.ordersRepo.create(command.userId, command.items);
    this.eventBus.publish(new OrderCreatedEvent(order.id));
    return order;
  }
}

// Query
export class GetOrderQuery implements IQuery {
  constructor(public readonly orderId: string) {}
}

@QueryHandler(GetOrderQuery)
export class GetOrderHandler implements IQueryHandler<GetOrderQuery> {
  async execute(query: GetOrderQuery): Promise<Order> {
    return this.ordersRepo.findOne(query.orderId);
  }
}

// Saga
@Injectable()
export class OrderSaga {
  @Saga()
  orderCreated = (events$: Observable<any>): Observable<ICommand> =>
    events$.pipe(
      filter(event => event instanceof OrderCreatedEvent),
      map(event => new SendConfirmationEmailCommand(event.orderId)),
    );
}
```

---

## Scheduling

```typescript
@Injectable()
export class TasksService {
  @Cron('0 0 * * 0')
  weeklyReport() { ... }

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT, { name: 'dailyCleanup' })
  dailyCleanup() { ... }

  @Interval(30_000)
  healthCheck() { ... }

  @Timeout(5_000)
  startupTask() { ... }
}
```

### Dynamic Job Management

```typescript
@Injectable()
export class DynamicTasksService {
  constructor(private schedulerRegistry: SchedulerRegistry) {}

  addJob(name: string, cronExpr: string, callback: () => void) {
    const job = new CronJob(cronExpr, callback);
    this.schedulerRegistry.addCronJob(name, job);
    job.start();
  }
}
```

---

## Queues (BullMQ)

```typescript
// Producer
@Injectable()
export class EmailProducer {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async sendWelcome(userId: string) {
    await this.emailQueue.add('welcome', { userId }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
    });
  }
}

// Consumer
@Processor('email')
export class EmailConsumer extends WorkerHost {
  async process(job: Job): Promise<void> {
    switch (job.name) {
      case 'welcome': await this.sendWelcomeEmail(job.data.userId); break;
    }
  }
}
```

---

## Caching

```typescript
// Module-level
CacheModule.registerAsync({
  isGlobal: true,
  useFactory: (config: ConfigService) => ({
    ttl: 60_000, max: 100,
  }),
  inject: [ConfigService],
});

// Controller-level
@UseInterceptors(CacheInterceptor)
@CacheTTL(120_000)
@Get('trending')
getTrending() { ... }

// Programmatic
@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async findById(id: string): Promise<Product> {
    const cached = await this.cache.get<Product>(`product:${id}`);
    if (cached) return cached;
    const product = await this.repo.findOneOrFail({ where: { id } });
    await this.cache.set(`product:${id}`, product, 300_000);
    return product;
  }
}
```

---

## Health Checks

```typescript
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private http: HttpHealthIndicator,
    private memory: MemoryHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.http.pingCheck('external-api', 'https://api.example.com/health'),
      () => this.memory.checkHeap('memory_heap', 300 * 1024 * 1024),
    ]);
  }
}
```

---

## Configuration

```typescript
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
      validationSchema: Joi.object({
        NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
        PORT: Joi.number().default(3000),
        JWT_SECRET: Joi.string().min(32).required(),
      }),
    }),
  ],
})
export class AppModule {}

// Typed namespace
export default registerAs('database', () => ({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
}));

// Usage
this.config.get<string>('database.host');
this.config.getOrThrow('JWT_SECRET');
```

---

## Swagger / OpenAPI

```typescript
const config = new DocumentBuilder()
  .setTitle('My API')
  .setVersion('1.0')
  .addBearerAuth()
  .build();
const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('api', app, document);

// DTO decorators
export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail() email: string;

  @ApiProperty({ minLength: 8 })
  @IsString() @MinLength(8) password: string;
}

// Controller
@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  @ApiResponse({ status: 200, type: User })
  @ApiResponse({ status: 404, description: 'Not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {}
}
```

Use the `@nestjs/swagger` CLI plugin in `nest-cli.json` to auto-generate `@ApiProperty` from class-validator decorators:

```json
{
  "compilerOptions": {
    "plugins": ["@nestjs/swagger"]
  }
}
```

---

## Versioning

```typescript
// URI: /v1/users
app.enableVersioning({ type: VersioningType.URI });

// Header: X-API-Version: 1
app.enableVersioning({ type: VersioningType.HEADER, header: 'X-API-Version' });

// Media type: Accept: application/json;v=1
app.enableVersioning({ type: VersioningType.MEDIA_TYPE, key: 'v=' });

@Controller({ path: 'users', version: '1' }) export class UsersV1Controller {}
@Controller({ path: 'users', version: '2' }) export class UsersV2Controller {}

// Multiple versions on one handler
@Version(['1', '2']) @Get() findAll() {}

// Version-neutral
@Version(VERSION_NEUTRAL) @Get() findAll() {}
```

---

## Key Architectural Decisions

**Scope selection:** Default to singleton. Use request scope only for per-request state (tenant, audit). Transient scope is rare.

**Guard vs Middleware:** Guards have `ExecutionContext` (metadata, handler references) and work across HTTP/WS/microservices. Middleware is HTTP-only and runs earlier. Use guards for authorization; middleware for request mutation.

**Interceptor vs Pipe:** Pipes transform/validate input parameters. Interceptors wrap the entire handler and can modify response streams.

**Dynamic modules:** Always expose `register` for sync config and `registerAsync` for factory-based config with DI.

**CQRS:** Only adopt when the domain has genuinely asymmetric read/write complexity. For CRUD, it adds ceremony without benefit.

**Testing:** Use `Test.createTestingModule` for unit tests. Reserve e2e tests for integration points. Mock at the provider level.
