# NestJS Best Practices, Testing, and Ecosystem Patterns

## Table of Contents
1. [Project Structure](#project-structure)
2. [Request Lifecycle](#request-lifecycle)
3. [Testing Patterns](#testing-patterns)
4. [Error Handling](#error-handling)
5. [Authentication Patterns](#authentication-patterns)
6. [Authorization](#authorization)
7. [Database Patterns](#database-patterns)
8. [Microservices Patterns](#microservices-patterns)
9. [Deployment](#deployment)
10. [Performance](#performance)
11. [Observability](#observability)
12. [Common Anti-Patterns](#common-anti-patterns)

---

## Project Structure

### Module-Based, Domain-Driven Layout

NestJS is built around Angular's module system. Each feature domain owns its module, controller, service, and DTOs. Avoid a flat `controllers/` folder — that pattern fights the framework.

```
src/
├── app.module.ts
├── main.ts
├── common/
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   ├── pipes/
│   └── dto/
├── config/
│   ├── app.config.ts
│   └── database.config.ts
├── modules/
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── strategies/
│   │   │   ├── jwt.strategy.ts
│   │   │   └── refresh.strategy.ts
│   │   └── dto/
│   │       ├── login.dto.ts
│   │       └── refresh-token.dto.ts
│   └── users/
│       ├── users.module.ts
│       ├── users.controller.ts
│       ├── users.service.ts
│       ├── users.repository.ts
│       └── dto/
│           ├── create-user.dto.ts
│           └── update-user.dto.ts
```

### Module Anatomy

```typescript
// users/users.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([User]), ConfigModule],
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService], // only export what other modules need
})
export class UsersModule {}
```

**Key rule:** Export only what other modules actually import. Over-exporting creates hidden coupling.

### Configuration with @nestjs/config

```typescript
// config/app.config.ts
export const appConfig = registerAs('app', () => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  env: process.env.NODE_ENV ?? 'development',
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
}));

// app.module.ts
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig],
      validationSchema: Joi.object({
        PORT: Joi.number().default(3000),
        JWT_SECRET: Joi.string().required(),
        DATABASE_URL: Joi.string().required(),
      }),
    }),
  ],
})
export class AppModule {}
```

---

## Request Lifecycle

The NestJS request pipeline runs in a fixed order. Understanding this prevents misplaced logic.

```
Incoming Request
  → Middleware         (express-style, runs before routing)
  → Guards            (authentication/authorization, return boolean)
  → Interceptors      (before handler: transform request, start timers)
  → Pipes             (validation and transformation of params/body)
  → Route Handler     (your controller method)
  → Interceptors      (after handler: transform response, log duration)
  → Exception Filters (catch errors thrown anywhere above)
  → Response
```

### Middleware

```typescript
// common/middleware/logger.middleware.ts
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  private logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction) {
    const { method, originalUrl } = req;
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      this.logger.log(`${method} ${originalUrl} ${res.statusCode} ${duration}ms`);
    });
    next();
  }
}

// app.module.ts — apply selectively
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
```

### Guards

```typescript
// Guards run before interceptors and pipes
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }

  handleRequest(err: any, user: any) {
    if (err || !user) throw err ?? new UnauthorizedException();
    return user;
  }
}
```

### Interceptors

```typescript
// Transform every response into a standard envelope
@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiResponse<T>> {
    return next.handle().pipe(
      map((data) => ({ success: true, data, timestamp: new Date().toISOString() })),
    );
  }
}
```

### Pipes

```typescript
// Validate and transform request body globally
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,          // strip unknown properties
      forbidNonWhitelisted: true,
      transform: true,          // auto-transform to DTO class instances
      transformOptions: { enableImplicitConversion: true },
    }),
  );
}
```

---

## Testing Patterns

### Unit Testing Services with TestingModule

```typescript
// users/users.service.spec.ts
describe('UsersService', () => {
  let service: UsersService;
  let repository: jest.Mocked<UsersRepository>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: UsersRepository,
          useValue: {
            findOne: jest.fn(),
            save: jest.fn(),
            findAll: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(UsersService);
    repository = module.get(UsersRepository);
  });

  it('throws NotFoundException when user not found', async () => {
    repository.findOne.mockResolvedValue(null);
    await expect(service.findById('missing-id')).rejects.toThrow(NotFoundException);
  });

  it('returns user when found', async () => {
    const user = { id: '1', email: 'test@example.com' } as User;
    repository.findOne.mockResolvedValue(user);
    const result = await service.findById('1');
    expect(result).toEqual(user);
    expect(repository.findOne).toHaveBeenCalledWith({ where: { id: '1' } });
  });
});
```

### Controller Testing

```typescript
// users/users.controller.spec.ts
describe('UsersController', () => {
  let controller: UsersController;
  let service: jest.Mocked<UsersService>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: { findById: jest.fn(), create: jest.fn() },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get(UsersController);
    service = module.get(UsersService);
  });

  it('calls service.findById with correct id', async () => {
    const user = { id: '1' } as User;
    service.findById.mockResolvedValue(user);
    const result = await controller.getUser('1');
    expect(service.findById).toHaveBeenCalledWith('1');
    expect(result).toBe(user);
  });
});
```

### E2E Testing with Database Isolation

```typescript
// test/users.e2e-spec.ts
describe('Users (e2e)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideModule(DatabaseModule)
      .useModule(TestDatabaseModule) // points to test DB
      .compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    dataSource = module.get(DataSource);
  });

  beforeEach(async () => {
    // Truncate in reverse FK order between tests
    await dataSource.query('DELETE FROM users');
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /users creates a user', async () => {
    const dto = { email: 'test@example.com', password: 'Secret123!' };
    const res = await request(app.getHttpServer())
      .post('/users')
      .send(dto)
      .expect(201);

    expect(res.body.data.email).toBe(dto.email);
    expect(res.body.data.password).toBeUndefined(); // not exposed
  });
});
```

### Mock Providers Pattern

```typescript
// Reusable mock factories
export const mockUsersService = (): Partial<UsersService> => ({
  findById: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
});

// In any test
providers: [{ provide: UsersService, useFactory: mockUsersService }]
```

---

## Error Handling

### Custom Exception Hierarchy

```typescript
// common/exceptions/base.exception.ts
export class AppException extends HttpException {
  constructor(
    message: string,
    status: HttpStatus,
    public readonly code: string,
    public readonly details?: unknown,
  ) {
    super({ message, code, details }, status);
  }
}

export class ResourceNotFoundException extends AppException {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, HttpStatus.NOT_FOUND, 'RESOURCE_NOT_FOUND');
  }
}

export class BusinessRuleViolationException extends AppException {
  constructor(message: string, details?: unknown) {
    super(message, HttpStatus.UNPROCESSABLE_ENTITY, 'BUSINESS_RULE_VIOLATION', details);
  }
}
```

### Global Exception Filter

```typescript
// common/filters/all-exceptions.filter.ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      message = typeof body === 'string' ? body : (body as any).message ?? message;
      code = (body as any).code ?? 'HTTP_ERROR';
    }

    if (status >= 500) {
      this.logger.error({ exception, path: request.url }, 'Unhandled exception');
    }

    response.status(status).json({
      success: false,
      error: { code, message },
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}

// main.ts
app.useGlobalFilters(new AllExceptionsFilter());
```

### Validation Pipe Error Shape

```typescript
// Extend ValidationPipe to standardize class-validator errors
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    transform: true,
    exceptionFactory: (errors) => {
      const details = errors.map((e) => ({
        field: e.property,
        constraints: Object.values(e.constraints ?? {}),
      }));
      throw new BadRequestException({ message: 'Validation failed', code: 'VALIDATION_ERROR', details });
    },
  }),
);
```

---

## Authentication Patterns

### JWT + Refresh Token Strategy

```typescript
// auth/strategies/jwt.strategy.ts
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get('app.jwtSecret'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    return { userId: payload.sub, email: payload.email, roles: payload.roles };
  }
}

// auth/strategies/refresh.strategy.ts
@Injectable()
export class RefreshTokenStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refreshToken'),
      ignoreExpiration: false,
      secretOrKey: config.get('app.jwtRefreshSecret'),
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: JwtPayload) {
    const refreshToken = req.body.refreshToken;
    return { ...payload, refreshToken };
  }
}

// auth/auth.service.ts
@Injectable()
export class AuthService {
  async login(user: User) {
    const payload: JwtPayload = { sub: user.id, email: user.email, roles: user.roles };
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload, { expiresIn: '15m' }),
      this.jwtService.signAsync(payload, {
        secret: this.config.get('app.jwtRefreshSecret'),
        expiresIn: '7d',
      }),
    ]);
    await this.storeHashedRefreshToken(user.id, refreshToken);
    return { accessToken, refreshToken };
  }

  async refresh(userId: string, refreshToken: string) {
    const user = await this.usersService.findById(userId);
    const isValid = await bcrypt.compare(refreshToken, user.hashedRefreshToken);
    if (!isValid) throw new UnauthorizedException('Refresh token invalid');
    return this.login(user);
  }
}
```

### OAuth2 (Google)

```typescript
@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(config: ConfigService) {
    super({
      clientID: config.get('google.clientId'),
      clientSecret: config.get('google.clientSecret'),
      callbackURL: config.get('google.callbackUrl'),
      scope: ['email', 'profile'],
    });
  }

  async validate(accessToken: string, refreshToken: string, profile: Profile) {
    const { emails, photos, name } = profile;
    return {
      email: emails[0].value,
      name: `${name.givenName} ${name.familyName}`,
      picture: photos[0].value,
      accessToken,
    };
  }
}
```

### API Key Authentication

```typescript
@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(private readonly apiKeyService: ApiKeyService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const key = request.headers['x-api-key'] as string;
    if (!key) throw new UnauthorizedException('API key required');
    const valid = await this.apiKeyService.validate(key);
    if (!valid) throw new UnauthorizedException('Invalid API key');
    return true;
  }
}
```

---

## Authorization

### RBAC with Guards and Decorators

```typescript
// common/decorators/roles.decorator.ts
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);

// common/guards/roles.guard.ts
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required?.length) return true;

    const { user } = context.switchToHttp().getRequest();
    return required.some((role) => user.roles.includes(role));
  }
}

// Usage on controller
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Delete(':id')
remove(@Param('id') id: string) {
  return this.usersService.remove(id);
}
```

### CASL Integration (Policy-Based)

```typescript
// auth/casl/casl-ability.factory.ts
export type AppAbility = MongoAbility<[Action, Subjects]>;

@Injectable()
export class CaslAbilityFactory {
  createForUser(user: AuthenticatedUser): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    if (user.roles.includes(Role.ADMIN)) {
      can(Action.Manage, 'all');
    } else {
      can(Action.Read, User);
      can(Action.Update, User, { id: user.userId }); // own record only
      cannot(Action.Delete, User).because('Users cannot delete accounts');
    }

    return build({ detectSubjectType: (item) => item.constructor as ExtractSubjectType<Subjects> });
  }
}

// common/guards/policy.guard.ts
@Injectable()
export class PoliciesGuard implements CanActivate {
  constructor(private reflector: Reflector, private factory: CaslAbilityFactory) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const policies = this.reflector.get<PolicyHandler[]>('policies', context.getHandler()) ?? [];
    const { user } = context.switchToHttp().getRequest();
    const ability = this.factory.createForUser(user);
    return policies.every((handler) => handler(ability));
  }
}

// Usage
@CheckPolicies((ability) => ability.can(Action.Update, User))
@Patch(':id')
update(@Param('id') id: string, @Body() dto: UpdateUserDto) { ... }
```

---

## Database Patterns

### TypeORM Repository Pattern

```typescript
// users/users.repository.ts
@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  async findActiveUsers(page: number, limit: number): Promise<[User[], number]> {
    return this.repo.findAndCount({
      where: { isActive: true, deletedAt: IsNull() },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
      relations: ['roles'],
    });
  }

  async findByEmailWithPassword(email: string): Promise<User | null> {
    return this.repo
      .createQueryBuilder('user')
      .addSelect('user.password') // password is @Column({ select: false })
      .where('user.email = :email', { email })
      .getOne();
  }
}
```

### Transactions with TypeORM

```typescript
// Wrap multiple operations in a transaction
@Injectable()
export class OrdersService {
  constructor(private readonly dataSource: DataSource) {}

  async createOrder(dto: CreateOrderDto): Promise<Order> {
    return this.dataSource.transaction(async (manager) => {
      const order = manager.create(Order, dto);
      await manager.save(order);

      await manager.decrement(Product, { id: dto.productId }, 'stock', dto.quantity);

      const payment = manager.create(Payment, { orderId: order.id, amount: dto.total });
      await manager.save(payment);

      return order;
    });
  }
}
```

### Prisma Service Pattern

```typescript
// prisma/prisma.service.ts
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  async cleanDatabase() {
    if (process.env.NODE_ENV !== 'test') throw new Error('cleanDatabase only in test env');
    const tables = await this.$queryRaw<{ tablename: string }[]>`
      SELECT tablename FROM pg_tables WHERE schemaname='public'
    `;
    await Promise.all(tables.map((t) => this.$executeRawUnsafe(`TRUNCATE TABLE "${t.tablename}" CASCADE`)));
  }
}

// users/users.service.ts with Prisma
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(params: { page: number; limit: number }) {
    const { page, limit } = params;
    const [data, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({ skip: (page - 1) * limit, take: limit }),
      this.prisma.user.count(),
    ]);
    return { data, total, page, limit };
  }
}
```

### Mongoose Schema Pattern

```typescript
// users/schemas/user.schema.ts
@Schema({ timestamps: true, versionKey: false })
export class User {
  @Prop({ required: true, unique: true, lowercase: true })
  email: string;

  @Prop({ required: true, select: false })
  password: string;

  @Prop({ type: [String], enum: Role, default: [Role.USER] })
  roles: Role[];
}

export const UserSchema = SchemaFactory.createForClass(User);

// Add index
UserSchema.index({ email: 1 });

// users/users.module.ts
@Module({
  imports: [MongooseModule.forFeature([{ name: User.name, schema: UserSchema }])],
  providers: [UsersService],
})
export class UsersModule {}
```

### Migrations

```
# TypeORM: generate from entity changes
npx typeorm migration:generate src/migrations/AddUserRefreshToken -d src/data-source.ts

# Run migrations in production (not synchronize: true — never in prod)
npx typeorm migration:run -d src/data-source.ts
```

---

## Microservices Patterns

### Hybrid Application (HTTP + Microservice)

```typescript
// main.ts — serve both HTTP and a message broker
async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.connectMicroservice<MicroserviceOptions>({
    transport: Transport.RMQ,
    options: {
      urls: [process.env.RABBITMQ_URL],
      queue: 'orders_queue',
      queueOptions: { durable: true },
    },
  });

  await app.startAllMicroservices();
  await app.listen(3000);
}
```

### Message Patterns (Request/Response)

```typescript
// orders/orders.controller.ts
@Controller()
export class OrdersController {
  @MessagePattern({ cmd: 'get_order' })
  async getOrder(@Payload() data: { id: string }): Promise<Order> {
    return this.ordersService.findById(data.id);
  }
}

// Client usage in another service
@Injectable()
export class ApiGatewayService {
  constructor(@Inject('ORDERS_SERVICE') private readonly client: ClientProxy) {}

  async getOrder(id: string): Promise<Order> {
    return firstValueFrom(this.client.send({ cmd: 'get_order' }, { id }));
  }
}
```

### Event Patterns (Fire and Forget)

```typescript
// Emit event — no response expected
@EventPattern('user_registered')
async handleUserRegistered(@Payload() data: UserRegisteredEvent) {
  await this.emailService.sendWelcome(data.email);
  await this.analyticsService.track('user_registered', data);
}

// Publisher
this.client.emit('user_registered', { userId, email, createdAt: new Date() });
```

### Serialization

```typescript
// Ensure dates survive transport as ISO strings
app.connectMicroservice({
  transport: Transport.RMQ,
  options: {
    urls: [process.env.RABBITMQ_URL],
    queue: 'main',
    serializer: new OutboundResponseIdentitySerializer(),
    deserializer: new InboundMessageIdentityDeserializer(),
  },
});
```

---

## Deployment

### Dockerfile (Multi-Stage)

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/main"]
```

### PM2 Cluster Mode

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'api',
    script: 'dist/main.js',
    instances: 'max',        // one per CPU core
    exec_mode: 'cluster',
    max_memory_restart: '500M',
    env_production: {
      NODE_ENV: 'production',
    },
  }],
};
```

### Graceful Shutdown

```typescript
// main.ts
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks(); // handles SIGTERM/SIGINT

  // Give load balancer time to drain connections
  const shutdownTimeout = 10_000;
  process.on('SIGTERM', () => setTimeout(() => process.exit(0), shutdownTimeout));

  await app.listen(3000);
}
```

---

## Performance

### Fastify Adapter vs Express

```typescript
// main.ts — drop-in swap, ~20-30% throughput improvement
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';

const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
await app.listen(3000, '0.0.0.0'); // fastify needs explicit host

// Caveat: Express-only middleware (e.g. passport with sessions) needs shims
// Most Passport strategies work via @nestjs/passport — verify compatibility first
```

### Caching Strategies

```typescript
// Module-level cache with Redis
@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        store: redisStore,
        host: config.get('redis.host'),
        port: config.get('redis.port'),
        ttl: 60, // seconds
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}

// Decorator cache on route handler
@UseInterceptors(CacheInterceptor)
@CacheTTL(120)
@Get('trending')
getTrending() {
  return this.articlesService.getTrending();
}

// Manual cache in service for complex keys
@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async findById(id: string): Promise<Product> {
    const key = `product:${id}`;
    const cached = await this.cache.get<Product>(key);
    if (cached) return cached;

    const product = await this.repo.findOneOrFail({ where: { id } });
    await this.cache.set(key, product, 300);
    return product;
  }
}
```

### Lazy-Loaded Modules

```typescript
// Defer heavy modules (e.g., PDF generation) until first request
@Injectable()
export class ReportsController {
  constructor(private readonly lazyModuleLoader: LazyModuleLoader) {}

  @Get('export')
  async exportPdf() {
    const { PdfModule } = await import('./pdf/pdf.module');
    const moduleRef = await this.lazyModuleLoader.load(() => PdfModule);
    const pdfService = moduleRef.get(PdfService);
    return pdfService.generate();
  }
}
```

---

## Observability

### Structured Logging with Pino

```typescript
// main.ts
import { Logger } from 'nestjs-pino';

const app = await NestFactory.create(AppModule, { bufferLogs: true });
app.useLogger(app.get(Logger));

// app.module.ts
@Module({
  imports: [
    LoggerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        pinoHttp: {
          level: config.get('app.env') === 'production' ? 'info' : 'debug',
          transport: config.get('app.env') !== 'production'
            ? { target: 'pino-pretty' }
            : undefined,
          serializers: {
            req: (req) => ({ method: req.method, url: req.url, id: req.id }),
          },
        },
      }),
    }),
  ],
})
export class AppModule {}
```

### OpenTelemetry Tracing

```typescript
// tracing.ts — loaded BEFORE main.ts via --require
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-pg': { enabled: true },
    }),
  ],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());

// package.json script
// "start:prod": "node --require ./dist/tracing dist/main"
```

### Health Checks

```typescript
// health/health.module.ts
@Module({
  imports: [TerminusModule, HttpModule],
  controllers: [HealthController],
})
export class HealthModule {}

// health/health.controller.ts
@Controller('health')
export class HealthController {
  constructor(
    private readonly health: HealthCheckService,
    private readonly db: TypeOrmHealthIndicator,
    private readonly redis: MicroserviceHealthIndicator,
    private readonly http: HttpHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.pingCheck('redis', { transport: Transport.REDIS, options: { host: 'redis' } }),
      () => this.http.pingCheck('external-api', 'https://api.example.com/ping'),
    ]);
  }
}
```

---

## Common Anti-Patterns

### Circular Dependencies

```typescript
// BAD: ModuleA imports ModuleB, ModuleB imports ModuleA
// This causes "Nest can't resolve dependencies" errors

// FIX 1: Extract shared logic into a third module
// CommonModule exports SharedService; both modules import CommonModule

// FIX 2: forwardRef (last resort — it hides design problems)
@Module({
  imports: [forwardRef(() => AuthModule)],
})
export class UsersModule {}

// FIX 3: Use events to break the cycle
// Instead of UsersService calling AuthService and AuthService calling UsersService,
// emit an event and let the other side react
```

### God Modules

```typescript
// BAD: One AppModule that imports and provides everything
@Module({
  imports: [DatabaseModule, AuthModule, UsersModule, EmailModule, ...20 more],
  providers: [AuthService, UsersService, EmailService, ...40 more],
})
export class AppModule {} // This is a coordination module, not a feature module

// GOOD: Each feature is self-contained; AppModule just composes top-level feature modules
@Module({
  imports: [DatabaseModule, AuthModule, UsersModule, ProductsModule],
})
export class AppModule {}
// Each feature module owns its providers internally
```

### Over-Engineering with CQRS

```typescript
// BAD: Using CQRS for a simple CRUD API with 3 developers
// Creates: GetUserQuery, GetUserQueryHandler, GetUserResult,
//          UpdateUserCommand, UpdateUserCommandHandler — for a single findById call

// GOOD: Use CQRS when you actually need:
// - Event sourcing
// - Read/write model separation (different schemas or databases)
// - Complex domain with many commands affecting the same aggregate
// - Teams >10 working on the same bounded context

// Rule of thumb: start with service layer, introduce CQRS when the service
// methods hit 200+ lines or you need audit logs of every state change
```

### Not Scoping Providers Correctly

```typescript
// BAD: Using REQUEST scope unnecessarily
@Injectable({ scope: Scope.REQUEST }) // new instance per HTTP request
export class UsersService {} // This is usually stateless — DEFAULT scope is fine

// Request scope causes every provider in the injection chain to become REQUEST scoped
// (NestJS propagates scope upward), which destroys singleton benefits

// Use REQUEST scope only when you genuinely need per-request state:
// - Tenant-aware services that read from the request header
// - Audit logging that needs the current user from the request
```

### Exposing Entities Directly

```typescript
// BAD: Returning ORM entity from controller — leaks DB schema, can expose passwords
@Get(':id')
findOne(@Param('id') id: string): Promise<User> { // User is TypeORM entity
  return this.usersService.findById(id);
}

// GOOD: Map to a DTO / response class
@Get(':id')
async findOne(@Param('id') id: string): Promise<UserResponseDto> {
  const user = await this.usersService.findById(id);
  return plainToInstance(UserResponseDto, user, { excludeExtraneousValues: true });
}

// UserResponseDto uses @Expose() — only decorated fields are included
export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  // password is NOT @Expose()'d
}
```

### Synchronize: true in Production

```typescript
// BAD: Auto-syncs DB schema from entities — will DROP columns on entity changes
TypeOrmModule.forRoot({ synchronize: true }) // NEVER in production

// GOOD: Use migrations
TypeOrmModule.forRoot({
  synchronize: process.env.NODE_ENV === 'development', // only local
  migrations: ['dist/migrations/*.js'],
  migrationsRun: true, // auto-run on startup in production
})
```
