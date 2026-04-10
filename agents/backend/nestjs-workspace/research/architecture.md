# NestJS Framework Architecture and Patterns

> Target audience: Senior TypeScript developers. NestJS version: 10.x (2024+).

---

## Table of Contents

1. [Modules](#1-modules)
2. [Providers and Services](#2-providers-and-services)
3. [Controllers](#3-controllers)
4. [Dependency Injection](#4-dependency-injection)
5. [Middleware](#5-middleware)
6. [Guards](#6-guards)
7. [Interceptors](#7-interceptors)
8. [Pipes](#8-pipes)
9. [Exception Filters](#9-exception-filters)
10. [GraphQL Integration](#10-graphql-integration)
11. [WebSockets](#11-websockets)
12. [Microservices](#12-microservices)
13. [CQRS](#13-cqrs)
14. [Testing](#14-testing)
15. [Database Integrations](#15-database-integrations)
16. [Configuration](#16-configuration)
17. [Swagger / OpenAPI](#17-swagger--openapi)
18. [Authentication and Authorization](#18-authentication-and-authorization)
19. [Versioning](#19-versioning)
20. [Scheduling](#20-scheduling)
21. [Queues](#21-queues)
22. [Caching](#22-caching)
23. [Health Checks](#23-health-checks)

---

## 1. Modules

NestJS organizes code into cohesive **modules**. The root `AppModule` bootstraps everything; feature modules encapsulate domain logic.

### @Module Decorator

```typescript
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService], // expose to other modules
})
export class UsersModule {}
```

`imports` — other modules whose exports this module needs.  
`providers` — DI-registered services, guards, interceptors, etc.  
`controllers` — route handlers scoped to this module.  
`exports` — subset of providers re-exported for consumers.

### Dynamic Modules

Dynamic modules are factory modules that accept configuration at import time. The canonical pattern exposes both `register` (non-global) and `registerAsync` (async config) static methods.

```typescript
import { DynamicModule, Module } from '@nestjs/common';

export interface DatabaseOptions {
  host: string;
  port: number;
  database: string;
}

const DATABASE_OPTIONS = 'DATABASE_OPTIONS';

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
        {
          provide: DATABASE_OPTIONS,
          useFactory: options.useFactory,
          inject: options.inject ?? [],
        },
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
    database: config.get('DB_NAME'),
  }),
  inject: [ConfigService],
});
```

### Global Modules

Decorate with `@Global()` to make a module's exports available everywhere without explicit import. Use sparingly — it defeats the purpose of module encapsulation but is appropriate for truly cross-cutting concerns (logging, config, event bus).

```typescript
import { Global, Module } from '@nestjs/common';

@Global()
@Module({
  providers: [LoggerService],
  exports: [LoggerService],
})
export class LoggerModule {}
```

### Lazy Loading Modules

In serverless / CLI contexts you may want modules loaded on demand. Use `LazyModuleLoader` to avoid loading the entire dependency graph at startup.

```typescript
import { Injectable } from '@nestjs/common';
import { LazyModuleLoader } from '@nestjs/core';

@Injectable()
export class AppService {
  constructor(private readonly lazyModuleLoader: LazyModuleLoader) {}

  async doHeavyWork() {
    const { HeavyModule } = await import('./heavy/heavy.module');
    const moduleRef = await this.lazyModuleLoader.load(() => HeavyModule);
    const heavyService = moduleRef.get(HeavyService);
    return heavyService.process();
  }
}
```

Lazy-loaded modules cannot register controllers; they are provider-only.

---

## 2. Providers and Services

### @Injectable

Any class decorated with `@Injectable()` can be registered as a NestJS provider.

```typescript
import { Injectable } from '@nestjs/common';

@Injectable()
export class UsersService {
  private readonly users: User[] = [];

  findAll(): User[] {
    return this.users;
  }
}
```

### Custom Providers

#### Value Provider

```typescript
const mockUsersService = { findAll: () => [] };

@Module({
  providers: [
    { provide: UsersService, useValue: mockUsersService },
  ],
})
export class UsersModule {}
```

#### Class Provider (aliasing / swapping implementations)

```typescript
@Module({
  providers: [
    { provide: UsersService, useClass: MockUsersService },
  ],
})
export class UsersModule {}
```

#### Factory Provider

```typescript
@Module({
  providers: [
    {
      provide: 'ASYNC_CONNECTION',
      useFactory: async (config: ConfigService): Promise<Connection> => {
        return await createConnection(config.get('DB_URL'));
      },
      inject: [ConfigService],
    },
  ],
})
export class AppModule {}
```

#### Existing Provider (alias)

```typescript
{ provide: 'AliasService', useExisting: RealService }
```

### Injection Scopes

By default providers are **singleton** (shared across the entire application). Override with `scope`:

```typescript
import { Injectable, Scope } from '@nestjs/common';

@Injectable({ scope: Scope.REQUEST })   // new instance per HTTP request
export class RequestScopedService {}

@Injectable({ scope: Scope.TRANSIENT }) // new instance per injection
export class TransientService {}
```

Request-scoped providers inject the raw `REQUEST` object:

```typescript
import { Inject, Injectable, Scope } from '@nestjs/common';
import { REQUEST } from '@nestjs/core';
import { Request } from 'express';

@Injectable({ scope: Scope.REQUEST })
export class AuditService {
  constructor(@Inject(REQUEST) private readonly request: Request) {}

  getRequestId() {
    return this.request.headers['x-request-id'];
  }
}
```

Scope propagates upward: if a singleton depends on a request-scoped service, the singleton becomes request-scoped too. Design carefully.

---

## 3. Controllers

Controllers handle HTTP routing. Decorate a class with `@Controller('prefix')` and methods with HTTP verb decorators.

```typescript
import {
  Controller, Get, Post, Put, Delete, Patch,
  Body, Param, Query, Res, HttpCode, Header,
  ParseIntPipe, UseGuards, UseInterceptors,
} from '@nestjs/common';
import { Response } from 'express';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@Query('page') page = 1, @Query('limit') limit = 20) {
    return this.usersService.findAll({ page, limit });
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.findOne(id);
  }

  @Post()
  @HttpCode(201)
  @Header('Cache-Control', 'no-store')
  create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateUserDto) {
    return this.usersService.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.usersService.remove(id);
  }

  // Take manual control of the response object
  @Get('export')
  export(@Res() res: Response) {
    res.set('Content-Type', 'text/csv');
    res.send(this.usersService.exportCsv());
  }
}
```

Key parameter decorators:

| Decorator | Source |
|---|---|
| `@Body(key?)` | `req.body` or `req.body[key]` |
| `@Param(key?)` | `req.params` or `req.params[key]` |
| `@Query(key?)` | `req.query` or `req.query[key]` |
| `@Headers(key?)` | `req.headers` or header value |
| `@Ip()` | `req.ip` |
| `@HostParam(key)` | `req.hostname` |
| `@Req()` / `@Request()` | raw request |
| `@Res()` / `@Response()` | raw response (bypasses interceptors) |

When using `@Res()`, NestJS assumes you will manage the response manually. Pass `{ passthrough: true }` to still benefit from response interceptors:

```typescript
@Get()
findAll(@Res({ passthrough: true }) res: Response) {
  res.set('X-Custom', 'value');
  return this.usersService.findAll(); // framework still serializes this
}
```

---

## 4. Dependency Injection

### Constructor Injection (standard)

```typescript
@Injectable()
export class OrdersService {
  constructor(
    private readonly usersService: UsersService,
    private readonly mailerService: MailerService,
    @Inject('CONFIG') private readonly config: AppConfig,
  ) {}
}
```

### Property Injection

Used when a class cannot use constructor injection (e.g., base classes). Less preferred because it obscures dependencies.

```typescript
@Injectable()
export class BaseService {
  @Inject(LoggerService)
  protected readonly logger: LoggerService;
}
```

### Circular Dependencies

Circular deps cause Nest to fail at startup. Resolve with `forwardRef`:

```typescript
// a.service.ts
@Injectable()
export class AService {
  constructor(@Inject(forwardRef(() => BService)) private b: BService) {}
}

// b.service.ts
@Injectable()
export class BService {
  constructor(@Inject(forwardRef(() => AService)) private a: AService) {}
}

// Module — also needs forwardRef on the import side
@Module({
  imports: [forwardRef(() => BModule)],
  providers: [AService],
  exports: [AService],
})
export class AModule {}
```

Prefer refactoring circular deps away (extract a shared service) rather than relying on `forwardRef`.

### ModuleRef (dynamic resolution)

```typescript
import { ModuleRef } from '@nestjs/core';

@Injectable()
export class StrategyFactory {
  constructor(private moduleRef: ModuleRef) {}

  getStrategy(name: string): PaymentStrategy {
    return this.moduleRef.get<PaymentStrategy>(`${name}Strategy`, { strict: false });
  }
}
```

---

## 5. Middleware

Middleware runs before route handlers, analogous to Express middleware.

### Class-based Middleware

```typescript
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
    next();
  }
}
```

Apply in the module:

```typescript
import { MiddlewareConsumer, Module, NestModule, RequestMethod } from '@nestjs/common';

@Module({ controllers: [UsersController] })
export class UsersModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(LoggerMiddleware)
      .forRoutes({ path: 'users', method: RequestMethod.GET });

    // Or apply to all routes in a controller
    consumer.apply(AuthMiddleware).forRoutes(UsersController);
  }
}
```

### Functional Middleware

A plain function — no class, no DI. Use when you need no dependencies.

```typescript
export function correlationIdMiddleware(req: Request, res: Response, next: NextFunction) {
  req.headers['x-correlation-id'] ??= crypto.randomUUID();
  next();
}
```

### Global Middleware

```typescript
// main.ts
const app = await NestFactory.create(AppModule);
app.use(correlationIdMiddleware);
await app.listen(3000);
```

---

## 6. Guards

Guards determine whether a request proceeds. They implement `CanActivate` and return `boolean | Promise<boolean> | Observable<boolean>`.

### Basic Guard

```typescript
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';

@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    return Boolean(request.user);
  }
}
```

### Role-Based Guard with Custom Metadata

```typescript
// roles.decorator.ts
import { SetMetadata } from '@nestjs/common';
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// roles.guard.ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some(role => user?.roles?.includes(role));
  }
}

// Controller usage
@Controller('admin')
@Roles('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {}
```

### JWT Guard (Passport)

```typescript
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  // Optionally override handleRequest to customize error handling
  handleRequest(err: any, user: any) {
    if (err || !user) throw err ?? new UnauthorizedException();
    return user;
  }
}
```

Apply globally:

```typescript
app.useGlobalGuards(new JwtAuthGuard());
// Or via DI (preferred — allows injection):
// In AppModule providers: { provide: APP_GUARD, useClass: JwtAuthGuard }
```

---

## 7. Interceptors

Interceptors wrap around request/response using RxJS `Observable`. They can transform data, add logging, implement caching, or set timeouts.

```typescript
import {
  CallHandler, ExecutionContext, Injectable, NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map, tap, timeout, catchError } from 'rxjs/operators';

// Logging interceptor
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    const req = context.switchToHttp().getRequest();
    return next.handle().pipe(
      tap(() => console.log(`${req.method} ${req.url} — ${Date.now() - start}ms`)),
    );
  }
}

// Response mapping — wrap all responses in { data, timestamp }
@Injectable()
export class TransformInterceptor<T> implements NestInterceptor<T, { data: T; timestamp: string }> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<{ data: T; timestamp: string }> {
    return next.handle().pipe(
      map(data => ({ data, timestamp: new Date().toISOString() })),
    );
  }
}

// Timeout interceptor
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

Apply:
```typescript
@UseInterceptors(LoggingInterceptor)
@Controller('users')
export class UsersController {}

// Global (in AppModule):
{ provide: APP_INTERCEPTOR, useClass: LoggingInterceptor }
```

---

## 8. Pipes

Pipes transform or validate incoming data before it reaches the handler.

### Built-in Pipes

```typescript
import {
  ParseIntPipe, ParseUUIDPipe, ParseBoolPipe, ParseArrayPipe,
  ParseEnumPipe, DefaultValuePipe, ValidationPipe,
} from '@nestjs/common';

@Get(':id')
findOne(@Param('id', ParseUUIDPipe) id: string) {}

@Get()
filter(@Query('active', new DefaultValuePipe(true), ParseBoolPipe) active: boolean) {}
```

### ValidationPipe with class-validator

Install: `npm i class-validator class-transformer`

```typescript
// create-user.dto.ts
import { IsEmail, IsString, MinLength, IsOptional, IsEnum } from 'class-validator';
import { Transform } from 'class-transformer';

export enum UserRole { ADMIN = 'admin', USER = 'user' }

export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsString()
  @Transform(({ value }) => value?.trim())
  name?: string;
}

// main.ts — global ValidationPipe
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,          // strip unknown properties
    forbidNonWhitelisted: true,
    transform: true,          // auto-transform to DTO class instances
    transformOptions: { enableImplicitConversion: true },
    exceptionFactory: errors => new BadRequestException(errors),
  }),
);
```

### Custom Pipe

```typescript
import { ArgumentMetadata, BadRequestException, Injectable, PipeTransform } from '@nestjs/common';

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

## 9. Exception Filters

Exception filters catch errors thrown anywhere in the pipeline and convert them to HTTP responses.

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
import { HttpException, HttpStatus } from '@nestjs/common';

export class BusinessException extends HttpException {
  constructor(message: string, public readonly code: string) {
    super({ message, code, statusCode: HttpStatus.UNPROCESSABLE_ENTITY }, HttpStatus.UNPROCESSABLE_ENTITY);
  }
}
```

### @Catch Filter

```typescript
import {
  ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Internal server error';

    this.logger.error(exception);

    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message,
    });
  }
}

// Catch only specific exception types
@Catch(BusinessException)
export class BusinessExceptionFilter implements ExceptionFilter {
  catch(exception: BusinessException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    ctx.getResponse<Response>().status(422).json({
      error: exception.code,
      message: exception.message,
    });
  }
}
```

Register globally:
```typescript
app.useGlobalFilters(new AllExceptionsFilter());
// Or via DI: { provide: APP_FILTER, useClass: AllExceptionsFilter }
```

---

## 10. GraphQL Integration

### Setup (Code-First)

```bash
npm i @nestjs/graphql @nestjs/apollo @apollo/server graphql
```

```typescript
// app.module.ts
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';

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

### Object Type and Resolver

```typescript
// user.model.ts
import { Field, ID, ObjectType } from '@nestjs/graphql';

@ObjectType()
export class User {
  @Field(() => ID)
  id: string;

  @Field()
  email: string;

  @Field({ nullable: true })
  name?: string;
}

// users.resolver.ts
import { Args, ID, Mutation, Query, Resolver, Subscription } from '@nestjs/graphql';
import { PubSub } from 'graphql-subscriptions';

const pubSub = new PubSub();

@Resolver(() => User)
export class UsersResolver {
  constructor(private readonly usersService: UsersService) {}

  @Query(() => [User])
  users(): Promise<User[]> {
    return this.usersService.findAll();
  }

  @Query(() => User, { nullable: true })
  user(@Args('id', { type: () => ID }) id: string): Promise<User | null> {
    return this.usersService.findOne(id);
  }

  @Mutation(() => User)
  async createUser(@Args('input') input: CreateUserInput): Promise<User> {
    const user = await this.usersService.create(input);
    pubSub.publish('userCreated', { userCreated: user });
    return user;
  }

  @Subscription(() => User)
  userCreated() {
    return pubSub.asyncIterableIterator('userCreated');
  }
}

// Input type
import { InputType, Field } from '@nestjs/graphql';
import { IsEmail } from 'class-validator';

@InputType()
export class CreateUserInput {
  @Field()
  @IsEmail()
  email: string;
}
```

### Schema-First

```typescript
GraphQLModule.forRoot<ApolloDriverConfig>({
  driver: ApolloDriver,
  typePaths: ['**/*.graphql'],  // load .graphql SDL files
  definitions: {
    path: join(process.cwd(), 'src/graphql.ts'), // generate TS types
  },
});
```

---

## 11. WebSockets

```bash
npm i @nestjs/websockets @nestjs/platform-socket.io socket.io
```

```typescript
import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  MessageBody, ConnectedSocket, OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ namespace: '/chat', cors: { origin: '*' } })
export class ChatGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  afterInit(server: Server) {
    console.log('WebSocket server initialized');
  }

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    console.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('joinRoom')
  handleJoinRoom(@MessageBody() room: string, @ConnectedSocket() client: Socket) {
    client.join(room);
    return { event: 'joinedRoom', data: room };
  }

  @SubscribeMessage('sendMessage')
  handleMessage(
    @MessageBody() payload: { room: string; message: string },
    @ConnectedSocket() client: Socket,
  ) {
    this.server.to(payload.room).emit('message', {
      from: client.id,
      message: payload.message,
    });
  }
}
```

Guards, interceptors, and pipes all work with `@WebSocketGateway`. Apply with `@UseGuards`, `@UseInterceptors`, `@UsePipes` as usual.

---

## 12. Microservices

```bash
npm i @nestjs/microservices
```

### TCP Transport (simplest)

```typescript
// main.ts (microservice)
import { NestFactory } from '@nestjs/core';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';

const app = await NestFactory.createMicroservice<MicroserviceOptions>(AppModule, {
  transport: Transport.TCP,
  options: { host: 'localhost', port: 3001 },
});
await app.listen();

// Controller — MessagePattern for request/response, EventPattern for fire-and-forget
import { Controller } from '@nestjs/common';
import { MessagePattern, EventPattern, Payload } from '@nestjs/microservices';

@Controller()
export class MathController {
  @MessagePattern('add')
  accumulate(@Payload() data: { a: number; b: number }): number {
    return data.a + data.b;
  }

  @EventPattern('user.created')
  handleUserCreated(@Payload() user: any) {
    console.log('User created:', user);
  }
}

// Hybrid app (HTTP + Microservice in one process)
const app = await NestFactory.create(AppModule);
app.connectMicroservice<MicroserviceOptions>({
  transport: Transport.TCP,
  options: { port: 3001 },
});
await app.startAllMicroservices();
await app.listen(3000);
```

### Transport Layers

```typescript
// Redis
{ transport: Transport.REDIS, options: { host: 'localhost', port: 6379 } }

// NATS
{ transport: Transport.NATS, options: { servers: ['nats://localhost:4222'] } }

// Kafka
{
  transport: Transport.KAFKA,
  options: {
    client: { brokers: ['localhost:9092'] },
    consumer: { groupId: 'my-group' },
  },
}

// RabbitMQ
{
  transport: Transport.RMQ,
  options: {
    urls: ['amqp://localhost:5672'],
    queue: 'main_queue',
    queueOptions: { durable: false },
  },
}

// gRPC
{
  transport: Transport.GRPC,
  options: {
    package: 'users',
    protoPath: join(__dirname, 'users.proto'),
    url: 'localhost:5000',
  },
}
```

### Client (Sending Messages)

```typescript
import { Inject, Injectable } from '@nestjs/common';
import { ClientProxy } from '@nestjs/microservices';
import { firstValueFrom } from 'rxjs';

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

// Register the client in module
@Module({
  imports: [
    ClientsModule.register([
      { name: 'MATH_SERVICE', transport: Transport.TCP, options: { port: 3001 } },
    ]),
  ],
})
export class AppModule {}
```

---

## 13. CQRS

```bash
npm i @nestjs/cqrs
```

CQRS separates read (query) and write (command) concerns through a shared event bus.

```typescript
// command.ts
import { ICommand } from '@nestjs/cqrs';

export class CreateOrderCommand implements ICommand {
  constructor(
    public readonly userId: string,
    public readonly items: OrderItem[],
  ) {}
}

// command-handler.ts
import { CommandHandler, ICommandHandler, EventBus } from '@nestjs/cqrs';

@CommandHandler(CreateOrderCommand)
export class CreateOrderHandler implements ICommandHandler<CreateOrderCommand> {
  constructor(
    private readonly ordersRepo: OrdersRepository,
    private readonly eventBus: EventBus,
  ) {}

  async execute(command: CreateOrderCommand): Promise<Order> {
    const order = await this.ordersRepo.create(command.userId, command.items);
    this.eventBus.publish(new OrderCreatedEvent(order.id));
    return order;
  }
}

// query.ts + handler
import { IQuery, IQueryHandler, QueryHandler } from '@nestjs/cqrs';

export class GetOrderQuery implements IQuery {
  constructor(public readonly orderId: string) {}
}

@QueryHandler(GetOrderQuery)
export class GetOrderHandler implements IQueryHandler<GetOrderQuery> {
  async execute(query: GetOrderQuery): Promise<Order> {
    return this.ordersRepo.findOne(query.orderId);
  }
}

// event + saga
import { IEvent } from '@nestjs/cqrs';
export class OrderCreatedEvent implements IEvent {
  constructor(public readonly orderId: string) {}
}

import { Saga, ICommand } from '@nestjs/cqrs';
import { Observable } from 'rxjs';
import { filter, map } from 'rxjs/operators';

@Injectable()
export class OrderSaga {
  @Saga()
  orderCreated = (events$: Observable<any>): Observable<ICommand> => {
    return events$.pipe(
      filter(event => event instanceof OrderCreatedEvent),
      map(event => new SendConfirmationEmailCommand(event.orderId)),
    );
  };
}

// Wire up in module
@Module({
  imports: [CqrsModule],
  providers: [
    CreateOrderHandler,
    GetOrderHandler,
    OrderSaga,
    OrderCreatedHandler,
    SendConfirmationEmailHandler,
  ],
})
export class OrdersModule {}
```

Dispatch from a service or controller:

```typescript
constructor(private commandBus: CommandBus, private queryBus: QueryBus) {}

const order = await this.commandBus.execute(new CreateOrderCommand(userId, items));
const found  = await this.queryBus.execute(new GetOrderQuery(orderId));
```

---

## 14. Testing

```bash
npm i --save-dev @nestjs/testing supertest
```

### Unit Testing with TestingModule

```typescript
import { Test, TestingModule } from '@nestjs/testing';

describe('UsersService', () => {
  let service: UsersService;
  let repo: jest.Mocked<UsersRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: UsersRepository,
          useValue: {
            findOne: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repo = module.get(UsersRepository);
  });

  it('should find a user', async () => {
    repo.findOne.mockResolvedValue({ id: '1', email: 'a@b.com' } as User);
    const result = await service.findOne('1');
    expect(result.email).toBe('a@b.com');
    expect(repo.findOne).toHaveBeenCalledWith({ where: { id: '1' } });
  });
});
```

### Overriding Providers

```typescript
const module = await Test.createTestingModule({
  imports: [UsersModule],
})
  .overrideProvider(UsersRepository)
  .useValue(mockRepo)
  .overrideGuard(JwtAuthGuard)
  .useValue({ canActivate: () => true })
  .overridePipe(ValidationPipe)
  .useValue(new ValidationPipe({ transform: true }))
  .compile();
```

### E2E Testing with Supertest

```typescript
// users.e2e-spec.ts
import * as request from 'supertest';
import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';

describe('UsersController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(TypeOrmModule)
      .useValue(testDatabaseModule)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(() => app.close());

  it('POST /users — creates a user', () => {
    return request(app.getHttpServer())
      .post('/users')
      .send({ email: 'test@example.com', password: 'password123' })
      .expect(201)
      .expect(res => {
        expect(res.body.email).toBe('test@example.com');
        expect(res.body.password).toBeUndefined();
      });
  });
});
```

---

## 15. Database Integrations

### TypeORM

```bash
npm i @nestjs/typeorm typeorm pg
```

```typescript
// app.module.ts
TypeOrmModule.forRootAsync({
  imports: [ConfigModule],
  useFactory: (config: ConfigService) => ({
    type: 'postgres',
    host: config.get('DB_HOST'),
    port: config.get<number>('DB_PORT'),
    username: config.get('DB_USER'),
    password: config.get('DB_PASS'),
    database: config.get('DB_NAME'),
    entities: [__dirname + '/**/*.entity{.ts,.js}'],
    synchronize: config.get('NODE_ENV') !== 'production',
    migrations: [__dirname + '/migrations/*{.ts,.js}'],
    migrationsRun: true,
  }),
  inject: [ConfigService],
});

// user.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false })
  password: string;

  @CreateDateColumn()
  createdAt: Date;
}

// Feature module
TypeOrmModule.forFeature([User])

// Repository injection
@Injectable()
export class UsersService {
  constructor(@InjectRepository(User) private repo: Repository<User>) {}

  findByEmail(email: string) {
    return this.repo.findOne({ where: { email } });
  }
}
```

### Prisma

```bash
npm i @prisma/client && npm i -D prisma
```

```typescript
// prisma.service.ts
import { INestApplication, Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }

  async enableShutdownHooks(app: INestApplication) {
    this.$on('beforeExit' as never, async () => {
      await app.close();
    });
  }
}

// Usage
@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.user.findMany({ include: { posts: true } });
  }

  create(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({ data });
  }
}
```

### Mongoose

```bash
npm i @nestjs/mongoose mongoose
```

```typescript
// app.module.ts
MongooseModule.forRoot('mongodb://localhost/nest')

// user.schema.ts
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type UserDocument = User & Document;

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true, unique: true })
  email: string;

  @Prop()
  name: string;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Feature module
MongooseModule.forFeature([{ name: User.name, schema: UserSchema }])

// Service
@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private userModel: Model<UserDocument>) {}

  findAll() {
    return this.userModel.find().exec();
  }

  create(dto: CreateUserDto) {
    return new this.userModel(dto).save();
  }
}
```

---

## 16. Configuration

```bash
npm i @nestjs/config joi
```

```typescript
// app.module.ts
import { ConfigModule, ConfigService } from '@nestjs/config';
import * as Joi from 'joi';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
      validationSchema: Joi.object({
        NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
        PORT: Joi.number().default(3000),
        DB_HOST: Joi.string().required(),
        DB_PORT: Joi.number().default(5432),
        JWT_SECRET: Joi.string().min(32).required(),
      }),
      validationOptions: { allowUnknown: false },
    }),
  ],
})
export class AppModule {}

// Typed config namespace
export default registerAs('database', () => ({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
}));

// Usage
@Injectable()
export class AppService {
  constructor(private config: ConfigService) {
    const dbHost = this.config.get<string>('database.host');
    const port = this.config.get<number>('PORT', 3000); // with default
  }
}
```

For fully typed config, use `ConfigService.get<T>` with a typed schema or `@nestjs/config`'s typed configuration feature:

```typescript
// Typed namespace access
this.config.get<string>('database.host')
this.config.getOrThrow('JWT_SECRET') // throws if undefined
```

---

## 17. Swagger / OpenAPI

```bash
npm i @nestjs/swagger
```

```typescript
// main.ts
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

const config = new DocumentBuilder()
  .setTitle('My API')
  .setDescription('API description')
  .setVersion('1.0')
  .addBearerAuth()
  .build();

const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('api', app, document);

// DTO decorators
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  password: string;

  @ApiPropertyOptional({ enum: UserRole, default: UserRole.USER })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}

// Controller decorators
import {
  ApiTags, ApiOperation, ApiResponse, ApiBearerAuth,
  ApiParam, ApiQuery,
} from '@nestjs/swagger';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiResponse({ status: 200, type: User })
  @ApiResponse({ status: 404, description: 'User not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {}
}
```

Plugin (auto-generates `@ApiProperty` from class-validator decorators — reduces boilerplate significantly):

```json
// nest-cli.json
{
  "compilerOptions": {
    "plugins": ["@nestjs/swagger"]
  }
}
```

---

## 18. Authentication and Authorization

### Passport + JWT

```bash
npm i @nestjs/passport passport passport-jwt passport-local
npm i -D @types/passport-jwt @types/passport-local
npm i @nestjs/jwt
```

```typescript
// local.strategy.ts
import { Strategy } from 'passport-local';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  constructor(private authService: AuthService) {
    super({ usernameField: 'email' });
  }

  async validate(email: string, password: string): Promise<User> {
    const user = await this.authService.validateUser(email, password);
    if (!user) throw new UnauthorizedException();
    return user;
  }
}

// jwt.strategy.ts
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string }) {
    return { userId: payload.sub, email: payload.email };
  }
}

// auth.service.ts
@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async validateUser(email: string, password: string): Promise<User | null> {
    const user = await this.usersService.findByEmail(email);
    if (user && (await bcrypt.compare(password, user.password))) {
      return user;
    }
    return null;
  }

  login(user: User) {
    return {
      access_token: this.jwtService.sign(
        { sub: user.id, email: user.email },
        { expiresIn: '15m' },
      ),
    };
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
  providers: [AuthService, LocalStrategy, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
```

### CASL Authorization

```bash
npm i @casl/ability @casl/nestjs
```

```typescript
// ability.factory.ts
import { AbilityBuilder, createMongoAbility, MongoAbility } from '@casl/ability';
import { Injectable } from '@nestjs/common';

type Actions = 'manage' | 'create' | 'read' | 'update' | 'delete';
type Subjects = 'User' | 'Post' | 'all';

export type AppAbility = MongoAbility<[Actions, Subjects]>;

@Injectable()
export class AbilityFactory {
  createForUser(user: User): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    if (user.role === 'admin') {
      can('manage', 'all');
    } else {
      can('read', 'Post');
      can(['create', 'update', 'delete'], 'Post', { authorId: user.id });
      cannot('delete', 'Post', { published: true });
    }

    return build();
  }
}

// policies.guard.ts
@Injectable()
export class PoliciesGuard implements CanActivate {
  constructor(private reflector: Reflector, private abilityFactory: AbilityFactory) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const rules = this.reflector.get<PolicyHandler[]>('policies', context.getHandler()) ?? [];
    const req = context.switchToHttp().getRequest();
    const ability = this.abilityFactory.createForUser(req.user);
    return rules.every(handler => handler(ability));
  }
}
```

---

## 19. Versioning

```typescript
// main.ts
import { VersioningType } from '@nestjs/common';

// URI versioning: /v1/users
app.enableVersioning({ type: VersioningType.URI });

// Header versioning: X-API-Version: 1
app.enableVersioning({ type: VersioningType.HEADER, header: 'X-API-Version' });

// Media type versioning: Accept: application/json;v=1
app.enableVersioning({ type: VersioningType.MEDIA_TYPE, key: 'v=' });

// Controller-level
@Controller({ path: 'users', version: '1' })
export class UsersControllerV1 {}

@Controller({ path: 'users', version: '2' })
export class UsersControllerV2 {}

// Method-level override
@Get()
@Version('2')
findAllV2() {}

// Multiple versions on one handler
@Get()
@Version(['1', '2'])
findAll() {}

// Version-neutral (matches any)
@Get()
@Version(VERSION_NEUTRAL)
findAll() {}
```

---

## 20. Scheduling

```bash
npm i @nestjs/schedule
```

```typescript
// app.module.ts
import { ScheduleModule } from '@nestjs/schedule';
@Module({ imports: [ScheduleModule.forRoot()] })
export class AppModule {}

// tasks.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression, Interval, Timeout, SchedulerRegistry } from '@nestjs/schedule';

@Injectable()
export class TasksService {
  private readonly logger = new Logger(TasksService.name);

  // Cron expression
  @Cron('0 0 * * 0') // every Sunday at midnight
  weeklyReport() {
    this.logger.log('Generating weekly report...');
  }

  // Named cron using CronExpression enum
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT, { name: 'dailyCleanup' })
  dailyCleanup() {}

  // Interval (milliseconds)
  @Interval(30_000)
  healthCheck() {}

  // One-shot timeout
  @Timeout(5_000)
  startupTask() {}
}

// Dynamic job management
@Injectable()
export class DynamicTasksService {
  constructor(private schedulerRegistry: SchedulerRegistry) {}

  addJob(name: string, cronExpr: string, callback: () => void) {
    const job = new CronJob(cronExpr, callback);
    this.schedulerRegistry.addCronJob(name, job);
    job.start();
  }

  deleteJob(name: string) {
    this.schedulerRegistry.deleteCronJob(name);
  }
}
```

---

## 21. Queues

```bash
npm i @nestjs/bullmq bullmq
```

### BullMQ (modern, recommended over @nestjs/bull)

```typescript
// app.module.ts
import { BullModule } from '@nestjs/bullmq';

@Module({
  imports: [
    BullModule.forRoot({ connection: { host: 'localhost', port: 6379 } }),
    BullModule.registerQueue({ name: 'email' }),
    BullModule.registerQueue({ name: 'reports' }),
  ],
})
export class AppModule {}

// email.producer.ts
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class EmailProducer {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async sendWelcome(userId: string) {
    await this.emailQueue.add('welcome', { userId }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
      removeOnComplete: true,
    });
  }
}

// email.consumer.ts
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';

@Processor('email')
export class EmailConsumer extends WorkerHost {
  async process(job: Job): Promise<void> {
    switch (job.name) {
      case 'welcome':
        await this.sendWelcomeEmail(job.data.userId);
        break;
      default:
        throw new Error(`Unknown job: ${job.name}`);
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job) {
    console.log(`Job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error) {
    console.error(`Job ${job.id} failed:`, error);
  }
}
```

---

## 22. Caching

```bash
npm i @nestjs/cache-manager cache-manager
# For Redis:
npm i cache-manager-ioredis-yet ioredis
```

```typescript
// app.module.ts
import { CacheModule } from '@nestjs/cache-manager';

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      imports: [ConfigModule],
      useFactory: async (config: ConfigService) => ({
        ttl: 60_000, // ms
        max: 100,    // max items in memory store
        // Redis store:
        // store: await redisStore({ host: 'localhost', port: 6379 }),
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {}

// Controller-level caching
import { CacheInterceptor, CacheTTL, CacheKey } from '@nestjs/cache-manager';

@Controller('products')
@UseInterceptors(CacheInterceptor) // caches all GET responses by URL
export class ProductsController {
  @Get()
  @CacheTTL(120_000) // override TTL
  findAll() {}

  @Get('featured')
  @CacheKey('featured-products') // custom cache key
  @CacheTTL(300_000)
  featured() {}
}

// Programmatic cache access
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class ProductsService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async findFeatured(): Promise<Product[]> {
    const cached = await this.cache.get<Product[]>('featured');
    if (cached) return cached;

    const products = await this.repo.findFeatured();
    await this.cache.set('featured', products, 300_000);
    return products;
  }

  async invalidate(id: string) {
    await this.cache.del(`product:${id}`);
  }
}
```

---

## 23. Health Checks

```bash
npm i @nestjs/terminus
```

```typescript
// health.module.ts
import { TerminusModule } from '@nestjs/terminus';
import { HttpModule } from '@nestjs/axios';

@Module({
  imports: [TerminusModule, HttpModule],
  controllers: [HealthController],
})
export class HealthModule {}

// health.controller.ts
import {
  HealthCheck, HealthCheckService,
  TypeOrmHealthIndicator, HttpHealthIndicator,
  MemoryHealthIndicator, DiskHealthIndicator,
  MicroserviceHealthIndicator,
} from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private http: HttpHealthIndicator,
    private memory: MemoryHealthIndicator,
    private disk: DiskHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.http.pingCheck('external-api', 'https://api.example.com/health'),
      () => this.memory.checkHeap('memory_heap', 300 * 1024 * 1024), // 300MB
      () => this.disk.checkStorage('storage', { path: '/', thresholdPercent: 0.9 }),
    ]);
  }
}

// Custom health indicator
import { Injectable } from '@nestjs/common';
import { HealthIndicator, HealthIndicatorResult, HealthCheckError } from '@nestjs/terminus';

@Injectable()
export class RedisHealthIndicator extends HealthIndicator {
  constructor(private redisClient: Redis) {
    super();
  }

  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    try {
      await this.redisClient.ping();
      return this.getStatus(key, true);
    } catch (error) {
      throw new HealthCheckError('Redis check failed', this.getStatus(key, false, { error }));
    }
  }
}
```

The `/health` endpoint returns:

```json
{
  "status": "ok",
  "info": {
    "database": { "status": "up" },
    "memory_heap": { "status": "up" }
  },
  "error": {},
  "details": { ... }
}
```

---

## Request Lifecycle Summary

Understanding the order in which NestJS processes a request is essential for debugging and for placing logic correctly:

```
Incoming Request
  → Global Middleware
  → Module Middleware
  → Global Guards
  → Controller Guards
  → Route Guards
  → Global Interceptors (pre-handler)
  → Controller Interceptors (pre-handler)
  → Route Interceptors (pre-handler)
  → Global Pipes
  → Controller Pipes
  → Route Pipes
  → Parameter Pipes
  → Route Handler
  → Route Interceptors (post-handler)
  → Controller Interceptors (post-handler)
  → Global Interceptors (post-handler)
  → Exception Filters (on error: route → controller → global)
  → Response
```

Exception filters run in reverse scope order — route-level first, then controller, then global. For non-error paths, interceptors wrap the response from innermost to outermost on the way back.

---

## Key Architectural Decisions

**Scope selection**: Default to singleton scope. Use request scope only when you genuinely need per-request state (e.g., tracing, audit logging tied to the request identity). Transient scope is rare — typically for stateful helpers.

**Guard vs Middleware**: Guards have access to the `ExecutionContext` (including metadata, handler references) and work across HTTP/WS/microservices. Middleware is HTTP-only and runs earlier in the pipeline. Use guards for authorization logic; use middleware for request mutation (correlation IDs, body parsing, rate limiting via Express middleware).

**Interceptor vs Pipe**: Pipes transform/validate input parameters. Interceptors wrap the entire handler call and can modify both request and response streams. If you need to transform the final response shape, use an interceptor, not a pipe.

**Dynamic modules**: Expose `register` for synchronous config and `registerAsync` for factory-based config that requires injected services. Always export the `module` property on the returned `DynamicModule`.

**CQRS**: Only adopt CQRS when the domain has genuinely asymmetric read/write complexity or when event sourcing is required. For CRUD-heavy services, it adds ceremony without benefit.

**Testing**: Use `Test.createTestingModule` for unit tests — avoid spinning up a full app. Reserve E2E tests for integration points and critical flows. Mock at the provider level (`overrideProvider`) rather than mocking individual methods inside real implementations.
