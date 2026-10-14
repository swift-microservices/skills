#!/bin/bash
set -euo pipefail
mkdir -p acme-api/Sources/API
cat > acme-api/Sources/API/openapi.yaml <<'YAML'
openapi: 3.1.0
info:
  title: Acme API
  version: 1.0.0
servers:
  - url: https://api.acme.example/v1
paths:
  /auth/sessions:
    post:
      operationId: signIn
      summary: Sign in with an email address and password
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SignInRequest'
      responses:
        '200':
          description: Signed in.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthenticationResponse'
        default:
          $ref: '#/components/responses/Problem'
  /auth/refresh:
    post:
      operationId: refreshSession
      summary: Exchange the refresh token in the Authorization header for new tokens
      security:
        - refreshToken: []
      responses:
        '200':
          description: Tokens refreshed.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthenticationResponse'
        default:
          $ref: '#/components/responses/Problem'
  /items:
    get:
      operationId: listItems
      summary: List the catalogue
      security: []
      responses:
        '200':
          description: The catalogue.
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/ItemResponse'
        default:
          $ref: '#/components/responses/Problem'
  /profile:
    get:
      operationId: getProfile
      summary: The signed-in user's profile
      security:
        - bearerAuth: []
      responses:
        '200':
          description: The profile.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserResponse'
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
    SignInRequest:
      type: object
      required: [email, password]
      properties:
        email: { type: string }
        password: { type: string }
    AuthenticationResponse:
      type: object
      required: [accessToken, accessTokenExpiresAt, refreshToken, refreshTokenExpiresAt]
      properties:
        accessToken: { type: string }
        accessTokenExpiresAt: { type: string, format: date-time }
        refreshToken: { type: string }
        refreshTokenExpiresAt: { type: string, format: date-time }
    ItemResponse:
      type: object
      required: [id, name]
      properties:
        id: { $ref: '#/components/schemas/UUID' }
        name: { type: string }
    UserResponse:
      type: object
      required: [id, name, email]
      properties:
        id: { $ref: '#/components/schemas/UUID' }
        name: { type: string }
        email: { type: string }
YAML
