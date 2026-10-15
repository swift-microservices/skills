# The OpenAPI document

The document a surface serves and generates from, and the client contract it makes for every app that calls it. The rest of the surface is in [surface.md](surface.md).

## Contents

- [The OpenAPI document is the contract](#the-openapi-document-is-the-contract)
- [The document as a client contract](#the-document-as-a-client-contract)

## The OpenAPI document is the contract

Keep `openapi.yaml` beside `openapi-generator-config.yaml` in the directory of the target that serves it, where the generator plugin looks; never reach for a document elsewhere with `resources: [.copy("../../openapi.yaml")]`, whose path escapes the target.

```yaml
generate:
  - types
accessModifier: package
namingStrategy: idiomatic
typeOverrides:
  schemas:
    UUID: Foundation.UUID
nameOverrides:
  UUID: UUID
additionalImports:
  - struct Foundation.UUID
```

Generate types only and register routes by hand, so the framework's route groups carry the tiers; generated server stubs would be a second routing mechanism for the same endpoints. Use `package` access: the types cross target boundaries inside one package and never leave it. `namingStrategy: idiomatic` turns operation ids and schema names into Swift names (`getProfile`, `ItemResponse`).

Declare one `UUID` schema (`type: string`, `format: uuid`) and reference it wherever an id appears; the override decodes it straight into `UUID`, so no conversion parses id strings from the OpenAPI side. It fits the Foundation rule: the generated code already imports `struct Foundation.URL`, `Data`, and `Date` from full Foundation, so the override adds no linkage, and `UUID` is the same type hand-written code reaches through the conditional `FoundationEssentials` import. Record the generated code's Foundation import as the documented exception the [foundation reference](../../writing-swift-server-code/references/foundation.md#dependency-traits-that-pull-in-foundation) asks for.

The alternative, chosen once per project and never per route, is `generate: [types, server]` with `OpenAPIHummingbird` (or `OpenAPIVapor`), registering one implementation of the generated `APIProtocol` with `registerHandlers(on:)`. The compiler then proves handlers and document agree, at the cost of tiering by middleware on the generated transport instead of by route group.

One document per surface: one per `<Module>HTTP` in a monolith, which moves with the module the day it becomes a service; one in `<Service>HTTP`; one in a gateway's `API`. Every document declares the `Problem` schema it answers with (next section); the server encodes its own hand-written `Problem`, never the generated one, so several documents can declare the same schema without sharing a generated type. Unimplemented paths cost nothing while only types are generated, so the document can lead the implementation and serve as its checklist.

## The document as a client contract

The client SDK ([client-sdk.md](client-sdk.md)) and every other client generate from the same document, so each operation carries what a generator needs:

- An `operationId`, which names the generated method.
- A `security` entry matching the tier the route is registered in: `[]` for session-issuing and health routes, `[{}, {bearerAuth: []}]` for the identifying tier, `[{bearerAuth: []}]` for the requiring tier. A refresh route names its own scheme, because it carries a refresh token, not an access token.
- A `default` response referencing the shared `Problem` response: `application/problem+json` over a declared `Problem` schema, so every failure decodes.

The document declares `servers` whose URLs end in the version base path the root mounts (`/v1`), and its paths omit it:

```yaml
openapi: 3.1.0
info:
  title: <Project> API
  version: 1.0.0
servers:
  - url: https://api.example.com/v1
paths:
  /items/{id}:
    get:
      operationId: getItem
      security: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            $ref: '#/components/schemas/UUID'
      responses:
        '200':
          description: The item.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ItemResponse'
        default:
          $ref: '#/components/responses/Problem'
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    refreshToken:
      type: http
      scheme: bearer
  responses:
    Problem:
      description: RFC 9457 problem details.
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/Problem'
  schemas:
    UUID:
      type: string
      format: uuid
    Problem:
      type: object
      required: [type, title, status]
      properties:
        type: { type: string }
        title: { type: string }
        status: { type: integer }
        detail: { type: string }
        instance: { type: string }
    ItemResponse:
      type: object
      required: [id, name]
      properties:
        id: { $ref: '#/components/schemas/UUID' }
        name: { type: string }
```
