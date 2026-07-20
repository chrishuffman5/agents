# NestJS Best Practices Reference

## Project Structure

### Module-Based, Domain-Driven Layout

Each feature domain owns its module, controller, service, and DTOs. Avoid a flat `controllers/` folder -- that pattern fights the framework.

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
@Module({
  imports: [TypeOrmModule.forFeature([User]), ConfigModule],
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService], // only export what other modules need
})
export class UsersModule {}
```

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

## Testing Patterns

### Unit Testing Services with TestingModule

```typescript
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
describe('UsersController', () => {
  let controller: UsersController;
  let service: jest.Mocked<UsersService>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        { provide: UsersService, useValue: { findById: jest.fn(), create: jest.fn() } },
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
describe('Users (e2e)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideModule(DatabaseModule)
      .useModule(TestDatabaseModule)
      .compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    dataSource = module.get(DataSource);
  });

  beforeEach(async () => {
    await dataSource.query('DELETE FROM users');
  });

  afterAll(async () => { await app.close(); });

  it('POST /users creates a user', async () => {
    const dto = { email: 'test@example.com', password: 'Secret123!' };
    const res = await request(app.getHttpServer())
      .post('/users')
      .send(dto)
      .expect(201);
    expect(res.body.data.email).toBe(dto.email);
    expect(res.body.data.password).toBeUndefined();
  });
});
```

### Mock Provider Factories

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

### Provider Overrides

```typescript
const module = await Test.createTestingModule({ imports: [UsersModule] })
  .overrideProvider(UsersRepository).useValue(mockRepo)
  .overrideGuard(JwtAuthGuard).useValue({ canActivate: () => true })
  .overridePipe(ValidationPipe).useValue(new ValidationPipe({ transform: true }))
  .compile();
```

---

## Authentication Patterns

### JWT + Refresh Token Strategy

```typescript
// jwt.strategy.ts
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

// refresh.strategy.ts
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
    return { ...payload, refreshToken: req.body.refreshToken };
  }
}

// auth.service.ts
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

// auth.module.ts
@Module({
  imports: [
    UsersModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow('JWT_SECRET'),
        signOptions: { expiresIn: '15m' },
      }),
      inject: [ConfigService],
    }),
  ],
  providers: [AuthService, LocalStrategy, JwtStrategy, RefreshTokenStrategy],
  exports: [AuthService],
})
export class AuthModule {}
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
    return {
      email: profile.emails[0].value,
      name: `${profile.name.givenName} ${profile.name.familyName}`,
      picture: profile.photos[0].value,
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
// Decorator
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);

// Guard
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[]>('roles', [
      context.getHandler(), context.getClass(),
    ]);
    if (!required?.length) return true;
    const { user } = context.switchToHttp().getRequest();
    return required.some((role) => user.roles.includes(role));
  }
}

// Usage
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Delete(':id')
remove(@Param('id') id: string) { return this.usersService.remove(id); }
```

### CASL Integration (Policy-Based)

```typescript
@Injectable()
export class CaslAbilityFactory {
  createForUser(user: AuthenticatedUser): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);
    if (user.roles.includes(Role.ADMIN)) {
      can(Action.Manage, 'all');
    } else {
      can(Action.Read, User);
      can(Action.Update, User, { id: user.userId });
      cannot(Action.Delete, User).because('Users cannot delete accounts');
    }
    return build();
  }
}

// Guard
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
@Injectable()
export class UsersRepository {
  constructor(@InjectRepository(User) private readonly repo: Repository<User>) {}

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
    return this.repo.createQueryBuilder('user')
      .addSelect('user.password')
      .where('user.email = :email', { email })
      .getOne();
  }
}
```

### Transactions with TypeORM

```typescript
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
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() { await this.$connect(); }
  async onModuleDestroy() { await this.$disconnect(); }

  async cleanDatabase() {
    if (process.env.NODE_ENV !== 'test') throw new Error('cleanDatabase only in test env');
    const tables = await this.$queryRaw<{ tablename: string }[]>`
      SELECT tablename FROM pg_tables WHERE schemaname='public'
    `;
    await Promise.all(tables.map((t) => this.$executeRawUnsafe(`TRUNCATE TABLE "${t.tablename}" CASCADE`)));
  }
}

// Usage
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
@Schema({ timestamps: true, versionKey: false })
export class User {
  @Prop({ required: true, unique: true, lowercase: true }) email: string;
  @Prop({ required: true, select: false }) password: string;
  @Prop({ type: [String], enum: Role, default: [Role.USER] }) roles: Role[];
}

export const UserSchema = SchemaFactory.createForClass(User);
UserSchema.index({ email: 1 });

// Module
MongooseModule.forFeature([{ name: User.name, schema: UserSchema }])

// Service
@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private userModel: Model<UserDocument>) {}
  findAll() { return this.userModel.find().exec(); }
}
```

### Migrations

```bash
# TypeORM: generate from entity changes
npx typeorm migration:generate src/migrations/AddUserRefreshToken -d src/data-source.ts

# Run migrations (NEVER use synchronize: true in production)
npx typeorm migration:run -d src/data-source.ts
```

---

## Microservices Patterns

### Hybrid Application (HTTP + Microservice)

```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.connectMicroservice<MicroserviceOptions>({
    transport: Transport.RMQ,
    options: { urls: [process.env.RABBITMQ_URL], queue: 'orders_queue', queueOptions: { durable: true } },
  });
  await app.startAllMicroservices();
  await app.listen(3000);
}
```

### Message Patterns (Request/Response)

```typescript
@MessagePattern({ cmd: 'get_order' })
async getOrder(@Payload() data: { id: string }): Promise<Order> {
  return this.ordersService.findById(data.id);
}

// Client
async getOrder(id: string): Promise<Order> {
  return firstValueFrom(this.client.send({ cmd: 'get_order' }, { id }));
}
```

### Event Patterns (Fire and Forget)

```typescript
@EventPattern('user_registered')
async handleUserRegistered(@Payload() data: UserRegisteredEvent) {
  await this.emailService.sendWelcome(data.email);
}

// Publisher
this.client.emit('user_registered', { userId, email });
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
module.exports = {
  apps: [{
    name: 'api',
    script: 'dist/main.js',
    instances: 'max',
    exec_mode: 'cluster',
    max_memory_restart: '500M',
    env_production: { NODE_ENV: 'production' },
  }],
};
```

### Graceful Shutdown

```typescript
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  await app.listen(3000);
}
```

---

## Performance

### Fastify Adapter

```typescript
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
await app.listen(3000, '0.0.0.0');
```

~20-30% throughput improvement. Verify Express-only middleware compatibility first.

### Caching Strategies

```typescript
// Module-level Redis cache
CacheModule.registerAsync({
  isGlobal: true,
  useFactory: (config: ConfigService) => ({
    store: redisStore,
    host: config.get('redis.host'),
    port: config.get('redis.port'),
    ttl: 60,
  }),
  inject: [ConfigService],
});

// Route-level cache
@UseInterceptors(CacheInterceptor)
@CacheTTL(120)
@Get('trending')
getTrending() { ... }
```

### Lazy-Loaded Modules

```typescript
@Injectable()
export class ReportsController {
  constructor(private readonly lazyModuleLoader: LazyModuleLoader) {}

  @Get('export')
  async exportPdf() {
    const { PdfModule } = await import('./pdf/pdf.module');
    const moduleRef = await this.lazyModuleLoader.load(() => PdfModule);
    return moduleRef.get(PdfService).generate();
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
LoggerModule.forRootAsync({
  useFactory: (config: ConfigService) => ({
    pinoHttp: {
      level: config.get('app.env') === 'production' ? 'info' : 'debug',
      transport: config.get('app.env') !== 'production' ? { target: 'pino-pretty' } : undefined,
    },
  }),
  inject: [ConfigService],
});
```

### OpenTelemetry Tracing

```typescript
// tracing.ts -- loaded BEFORE main.ts via --require
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();

// "start:prod": "node --require ./dist/tracing dist/main"
```

---

## Common Anti-Patterns

### Circular Dependencies

```typescript
// BAD: ModuleA imports ModuleB, ModuleB imports ModuleA

// FIX 1: Extract shared logic into a third module
// FIX 2: Use events to break the cycle
// FIX 3: forwardRef (last resort -- hides design problems)
@Module({ imports: [forwardRef(() => AuthModule)] })
export class UsersModule {}
```

### God Modules

```typescript
// BAD: One AppModule with 40+ providers
@Module({
  providers: [AuthService, UsersService, EmailService, ...40_more],
})
export class AppModule {}

// GOOD: Each feature is self-contained; AppModule just composes
@Module({
  imports: [DatabaseModule, AuthModule, UsersModule, ProductsModule],
})
export class AppModule {}
```

### Over-Engineering with CQRS

```typescript
// BAD: Using CQRS for simple CRUD
// Creates: GetUserQuery, GetUserQueryHandler, GetUserResult -- for a single findById

// GOOD: Use CQRS when you actually need:
// - Event sourcing
// - Read/write model separation
// - Complex domain with many commands on same aggregate
// Start with service layer, introduce CQRS when services exceed 200+ lines
```

### Incorrect Provider Scoping

```typescript
// BAD: REQUEST scope when not needed -- destroys singleton performance
@Injectable({ scope: Scope.REQUEST })
export class UsersService {} // stateless, DEFAULT scope is fine

// Request scope propagates upward through injection chain
```

### Exposing Entities Directly

```typescript
// BAD: Returns ORM entity -- leaks DB schema, can expose passwords
@Get(':id')
findOne(@Param('id') id: string): Promise<User> { ... }

// GOOD: Map to response DTO
@Get(':id')
async findOne(@Param('id') id: string): Promise<UserResponseDto> {
  const user = await this.usersService.findById(id);
  return plainToInstance(UserResponseDto, user, { excludeExtraneousValues: true });
}
```

### synchronize: true in Production

```typescript
// BAD: Auto-syncs schema -- WILL drop columns on entity changes
TypeOrmModule.forRoot({ synchronize: true }) // NEVER in production

// GOOD: Use migrations
TypeOrmModule.forRoot({
  synchronize: process.env.NODE_ENV === 'development',
  migrations: ['dist/migrations/*.js'],
  migrationsRun: true,
})
```
