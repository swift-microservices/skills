# Shared protobufs and gRPC boundaries

The gRPC transport of a module or a service: the contract package, the contract's shape, the producer adapter in `<Module>GRPC` (`<Service>GRPC` when the module is a service), and the consumer adapter that lets one module or service call another. A gRPC-only monolith has one `<Module>GRPC` target per module and one `GRPCServer` in its executable registering every module's services, with the interceptors applied per proto service exactly as a service applies them; a module reached only by other modules in the same process has no gRPC target at all, because a local use-case call needs no contract.

## Contents

- Canonical proto package
- Contract design
- Producer adapter
- Consumer adapter

## Canonical proto package

Canonical `.proto` files have one home, nested by organization, module, and API version, and every consumer generates from that one home. Where the home is follows the shape. Default in microservices: a separate `<project>-protos` SwiftPM repository at `https://github.com/<organization>/<project>-protos.git`, consumed by tag, because two or more packages generate from the same contract. Alternative in a gRPC monolith: `Sources/<Module>GRPC/Protos/<organization>/<module>/v1/` inside the one package, with the same generator plugin on the `<Module>GRPC` target, because one package consumes them; the files move to `<project>-protos` unchanged the day a second package does, since the path below the target is the same. In the separate repository, give each service its own library target/product:

```text
<project>-protos/
  Package.swift
  Sources/
    CatalogProtos/
      CatalogProtos.swift
      grpc-swift-proto-generator-config.json
      <organization>/
        catalog/
          v1/
            catalog.proto
    AccountsProtos/
      AccountsProtos.swift
      grpc-swift-proto-generator-config.json
      <organization>/
        accounts/
          v1/
            accounts.proto
```

Match the file package declaration to its path:

```proto
syntax = "proto3";

package <organization>.catalog.v1;
```

Keep `v1` even for the first release. Make compatible additions within `v1`; create `v2` for breaking API changes. Never reuse removed field numbers or rename package identity casually.

Each target uses the `GRPCProtobufGenerator` plugin with this configuration:

```json
{
  "generate": {
    "clients": true,
    "servers": true,
    "messages": true
  },
  "generatedSource": {
    "accessLevel": "public"
  }
}
```

The proto package exports a `.library(name: "<Service>Protos", targets: ["<Service>Protos"])`. Its target directly depends on `GRPCCore`, `GRPCProtobuf`, and `SwiftProtobuf`. Keep an empty marker Swift file when SwiftPM needs a Swift source beside proto resources.

Release and tag the proto package before adding a remote dependency to producer and consumer. Do not use local path dependencies in the finished integration, and do not duplicate `.proto` files in service repositories: a contract has one home, and in microservices that home is never a service.

## Contract design

Name RPCs for business capabilities, not CRUD tables. Include only the fields consumers need.

For create operations, omit the entity identifier from the request when the service owns that entity. Let the owning database generate it and return it in the response entity. Keep identifiers as protobuf strings on the wire and parse or format UUIDs at the transport boundary. Format UUID strings lowercased on the wire in every service; Foundation's `uuidString` is uppercase, so convert with `.lowercased()` explicitly. Do not let a caller choose an owned entity identifier merely to make retries convenient; define a separate `idempotency_key` when the mutation can be retried:

```proto
message CreateItemRequest {
  string name = 1;
  string idempotency_key = 2;
}
```

Treat `idempotency_key` as required through producer validation even though proto3 strings default to empty. Name it for its transport semantics rather than leaking a caller concept such as `registration_id`. Each caller generates or derives one stable, namespaced key per logical operation and reuses it across retries. The key is not a secret, caller authentication, or permission to perform the mutation.

**One gRPC service per audience.** A contract has up to three services in the same proto file, named for who calls them, so the receiving side applies authentication per service and nothing per method:

| Service | Callers | Holds |
| --- | --- | --- |
| `<Entity>PublicService` | anyone | the session-issuing RPCs, sign-up, catalogue reads, a provider's webhook — everything reached before or without a token |
| `<Entity>Service` | a signed-in user | the user's own operations and the administrative ones; which is which is the use case's decision |
| `<Entity>InternalService` | another process | what a worker or another service does on the service's data with no user present |

Omit a service the contract has no callers for — a newsletter has a public and a user service and no internal one. An RPC both a user and a process call appears on both services with the same messages; the producer maps each to the use case's matching overload. Never fold the three into one service with a method list of exclusions: the split is what makes the interceptors apply structurally (see *One RPC service per audience* in [identity-and-access.md](identity-and-access.md)). There is no RPC that issues a token to a process, because a process is proved by its certificate.

## Producer adapter

Implement the generated `SimpleServiceProtocol` in `<Module>GRPC`. Inject use-case protocol existentials, not databases or repositories:

```swift
package struct ItemService: <Organization>_Catalog_V1_ItemService.SimpleServiceProtocol {
    private let createItemUseCase: any CreateItemUseCaseProtocol
    private let listItemsUseCase: any ListItemsUseCaseProtocol

    package init(
        createItemUseCase: any CreateItemUseCaseProtocol,
        listItemsUseCase: any ListItemsUseCaseProtocol
    ) {
        self.createItemUseCase = createItemUseCase
        self.listItemsUseCase = listItemsUseCase
    }
}
```

One conformance per proto service: `ItemPublicService`, `ItemService`, `ItemInternalService`, each holding only the use cases its audience reaches. A handler on the user or internal service first insists on the principal the interceptor bound — a private `requireUser()` or `requireService()` reading `ServiceContext`, refusing with `.unauthenticated` (see *Identifying a caller versus requiring one* in [identity-and-access.md](identity-and-access.md)) — then translates the request to a use-case input, calls the use case with `subject:` or `service:`, and translates typed failures explicitly:

```swift
package func getItem(request: …, context: ServerContext) async throws -> … {
    let subject = try requireUser()

    do {
        let item = try await getItemUseCase(subject: subject, input: GetItemUseCaseInput(request: request))
        return <Organization>_Catalog_V1_Item(item: item)
    } catch GetItemUseCaseError.forbidden {
        throw RPCError(code: .permissionDenied, message: "An item may be read by its owner only.")
    } catch GetItemUseCaseError.itemNotFound {
        throw RPCError(code: .notFound, message: "The item was not found.")
    } catch GetItemUseCaseError.unknown {
        throw RPCError(code: .internalError, message: "The item could not be obtained.")
    }
}
```

| Use-case failure | gRPC code |
| --- | --- |
| invalid input | `.invalidArgument` |
| duplicate/conflict | `.alreadyExists` |
| idempotency key reused with different input | `.failedPrecondition` |
| missing entity | `.notFound` |
| no principal bound (the handler's guard) | `.unauthenticated` |
| the use case's `.forbidden` | `.permissionDenied` |
| unexpected internal failure | `.internalError` |

Keep stable, non-sensitive messages. Do not expose database errors.

Keep the service implementation at the feature root. Put conversions in a feature-local `Protobuf/` directory:

```swift
// Sources/CatalogGRPC/Items/Protobuf/Item+Protobuf.swift
extension <Organization>_Catalog_V1_Item {
    init(item: Item) {
        self.init()
        self.id = item.id.uuidString.lowercased()
        self.name = item.name
        self.creationDate = Google_Protobuf_Timestamp(date: item.creationDate)
    }
}
```

Map each request to its use-case input in a semantic `XUseCaseInput+Protobuf.swift` file. Perform transport validation — UUID parsing, integer range checks, enum recognition, timestamp conversion — in that initializer instead of adding generic free helpers to the service implementation:

```swift
// Sources/CatalogGRPC/Items/Protobuf/CreateItemUseCaseInput+Protobuf.swift
extension CreateItemUseCaseInput {
    init(request: <Organization>_Catalog_V1_CreateItemRequest) throws {
        self.init(name: request.name, idempotencyKey: request.idempotencyKey)
    }
}
```

Refuse an enum value the service cannot interpret rather than reading it as a default: `.unspecified` is an unset field and `.UNRECOGNIZED` is a value added to the contract after this service was built, and mapping either to the least-privileged case silently changes meaning.

Do not mark a conversion extension `private` when another file in the GRPC target calls it. Use only one `Protobuf/` level per feature; do not add request/response subdivisions or generic `Mappings` and `Adapters` folders.

## Consumer adapter

A consumer declares the use-case protocol it needs in its own Core, and what is injected behind it is the shape's decision: in a monolith the composition root injects the producer module's use case itself, a local call; between services it injects this adapter, over a client. Keep the consumer's caller-facing use-case protocol, input, error, and local entity in either case, so moving from the first to the second replaces only the concrete implementation:

```swift
package struct ListCatalogItemsUseCase: ListCatalogItemsUseCaseProtocol {
    private let client: <Organization>_Catalog_V1_ItemService.ClientProtocol

    package init<Transport>(client: GRPCClient<Transport>) {
        self.client = <Organization>_Catalog_V1_ItemService.Client(wrapping: client)
    }

    package func callAsFunction() async throws -> [Item] {
        let response = try await client.listItems(.init())
        return try response.items.map { message in
            guard let id = UUID(uuidString: message.id) else {
                throw ListCatalogItemsUseCaseError.malformedResponse
            }
            return Item(id: id, name: message.name, creationDate: message.creationDate.date)
        }
    }
}
```

Catch `RPCError` and map known status codes to the existing local use-case error. Do not catch old repository errors after the implementation becomes remote. Decide how unavailable/deadline failures appear to the caller; do not silently collapse all transport failures into a business conflict, and do not funnel them into a single `.unavailable` case (see *Boundary rules* in [architecture.md](architecture.md)).

Construct one long-lived `GRPCClient` per upstream in the consuming executable, wrap it in one generated service client per proto service the consumer speaks, inject those, and add the client to `ServiceGroup`. Do not create a client per request. Apply `BearerPropagationInterceptor<UserIdentity>` on the client through `interceptorPipeline`, to the upstream's user-service descriptors alone, never per call; a client that speaks as the process to an internal service carries no interceptor (see *Propagating the caller* in [identity-and-access.md](identity-and-access.md)).

Use deadlines and retry policy only from explicit latency and idempotency requirements. Never automatically retry a non-idempotent mutation without a contract-level idempotency design. Generate or derive the key once outside the retry loop; do not produce a new key for each attempt.
