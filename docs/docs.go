package docs

import "github.com/swaggo/swag"

const docTemplate = `{
  "schemes": {{ marshal .Schemes }},
  "swagger": "2.0",
  "info": {
    "description": "Backend API for EasyTranslator: games, translations, Steam lookup cache, auth, notifications, moderation, chat, and scanner callbacks.",
    "title": "EasyTranslator API",
    "contact": {},
    "version": "1.0"
  },
  "host": "{{ .Host }}",
  "basePath": "{{ .BasePath }}",
  "paths": {
    "/": {
      "get": {
        "summary": "Health check",
        "tags": ["System"],
        "produces": ["text/plain"],
        "responses": { "200": { "description": "API is running" } }
      }
    },
    "/api/auth/register": {
      "post": {
        "summary": "Register user",
        "tags": ["Auth"],
        "consumes": ["application/json"],
        "produces": ["application/json"],
        "parameters": [{ "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/RegisterRequest" } }],
        "responses": {
          "201": { "description": "Created", "schema": { "$ref": "#/definitions/RegisterResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/api/auth/login": {
      "post": {
        "summary": "Login user",
        "tags": ["Auth"],
        "consumes": ["application/json"],
        "produces": ["application/json"],
        "parameters": [{ "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/LoginRequest" } }],
        "responses": {
          "200": { "description": "JWT token", "schema": { "$ref": "#/definitions/LoginResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "401": { "description": "Unauthorized", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "403": { "description": "Forbidden", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/api/auth/me": {
      "get": {
        "summary": "Get current user",
        "tags": ["Auth"],
        "security": [{ "BearerAuth": [] }],
        "produces": ["application/json"],
        "responses": {
          "200": { "description": "Current user", "schema": { "$ref": "#/definitions/MeResponse" } },
          "401": { "description": "Unauthorized", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/cards": {
      "get": {
        "summary": "List game cards",
        "tags": ["Games"],
        "produces": ["application/json"],
        "responses": { "202": { "description": "Game cards", "schema": { "type": "array", "items": { "$ref": "#/definitions/GameCard" } } } }
      }
    },
    "/games": {
      "get": {
        "summary": "List public games with approved translations",
        "tags": ["Games"],
        "produces": ["application/json"],
        "responses": { "202": { "description": "Games", "schema": { "type": "array", "items": { "$ref": "#/definitions/PublicGameInfo" } } } }
      }
    },
    "/games/gsgi/{gameTitle}": {
      "get": {
        "summary": "Find Steam game by title",
        "description": "Looks up a game in the local Steam lookup cache first. On cache miss, requests Steam Store search, saves the first result, and returns Steam title plus app id.",
        "tags": ["Steam"],
        "produces": ["application/json"],
        "parameters": [{ "name": "gameTitle", "in": "path", "required": true, "type": "string" }],
        "responses": {
          "200": { "description": "Steam game info", "schema": { "$ref": "#/definitions/SteamGameInfo" } },
          "400": { "description": "Bad request or nothing found", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "500": { "description": "Steam request or cache error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/games/{gameid}": {
      "get": {
        "summary": "Get game by id",
        "tags": ["Games"],
        "produces": ["application/json"],
        "parameters": [{ "name": "gameid", "in": "path", "required": true, "type": "integer" }],
        "responses": {
          "202": { "description": "Game", "schema": { "$ref": "#/definitions/GameInfo" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      },
      "delete": {
        "summary": "Delete game",
        "tags": ["Games"],
        "security": [{ "BearerAuth": [] }],
        "produces": ["application/json"],
        "parameters": [{ "name": "gameid", "in": "path", "required": true, "type": "integer" }],
        "responses": {
          "200": { "description": "Deleted", "schema": { "$ref": "#/definitions/MessageResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "401": { "description": "Unauthorized", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "403": { "description": "Forbidden", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "500": { "description": "Server error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/games/add": {
      "post": {
        "summary": "Create game",
        "description": "Creates a game card and detailed game record. Steam AppID is optional. If a game with the same title already exists, returns 409 with status alreadycreated and existing game id.",
        "tags": ["Games"],
        "security": [{ "BearerAuth": [] }],
        "consumes": ["multipart/form-data"],
        "produces": ["application/json"],
        "parameters": [
          { "name": "Title", "in": "formData", "required": true, "type": "string" },
          { "name": "steamAppId", "in": "formData", "required": false, "type": "integer", "format": "int64" },
          { "name": "steamDeckCommand", "in": "formData", "required": false, "type": "string" },
          { "name": "big_pic", "in": "formData", "required": true, "type": "file" },
          { "name": "small_pic", "in": "formData", "required": true, "type": "file" }
        ],
        "responses": {
          "201": { "description": "Created", "schema": { "$ref": "#/definitions/CreateGameResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "409": { "description": "Game already exists", "schema": { "$ref": "#/definitions/DuplicateGameResponse" } },
          "500": { "description": "Server error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/games/translate/{gameid}": {
      "post": {
        "summary": "Upload translation archive",
        "tags": ["Translations"],
        "security": [{ "BearerAuth": [] }],
        "consumes": ["multipart/form-data"],
        "produces": ["application/json"],
        "parameters": [
          { "name": "gameid", "in": "path", "required": true, "type": "integer" },
          { "name": "file", "in": "formData", "required": true, "type": "file" },
          { "name": "authorName", "in": "formData", "type": "string" },
          { "name": "source", "in": "formData", "type": "string" },
          { "name": "version", "in": "formData", "type": "number", "format": "double" },
          { "name": "percentReady", "in": "formData", "type": "number", "format": "double" }
        ],
        "responses": {
          "201": { "description": "Created and queued for scan", "schema": { "$ref": "#/definitions/CreateTranslationResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "401": { "description": "Unauthorized", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "409": { "description": "Duplicate archive", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "500": { "description": "Server error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/games/translate/{transid}": {
      "delete": {
        "summary": "Delete translation",
        "tags": ["Translations"],
        "security": [{ "BearerAuth": [] }],
        "produces": ["application/json"],
        "parameters": [{ "name": "transid", "in": "path", "required": true, "type": "integer" }],
        "responses": {
          "200": { "description": "Deleted", "schema": { "$ref": "#/definitions/MessageResponse" } },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "404": { "description": "Not found", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "500": { "description": "Server error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/download/{transid}": {
      "get": {
        "summary": "Download translation archive",
        "tags": ["Translations"],
        "parameters": [
          { "name": "transid", "in": "path", "required": true, "type": "integer" },
          { "name": "token", "in": "query", "type": "string", "description": "Optional JWT token for browser downloads" }
        ],
        "responses": {
          "200": { "description": "File" },
          "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "403": { "description": "Forbidden", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "404": { "description": "Not found", "schema": { "$ref": "#/definitions/ErrorResponse" } },
          "500": { "description": "Server error", "schema": { "$ref": "#/definitions/ErrorResponse" } }
        }
      }
    },
    "/api/admin/users": {
      "get": {
        "summary": "List users",
        "tags": ["Admin"],
        "security": [{ "BearerAuth": [] }],
        "produces": ["application/json"],
        "parameters": [
          { "name": "page", "in": "query", "type": "integer" },
          { "name": "limit", "in": "query", "type": "integer" }
        ],
        "responses": { "200": { "description": "Users" }, "403": { "description": "Forbidden", "schema": { "$ref": "#/definitions/ErrorResponse" } } }
      }
    },
    "/api/admin/users/{userid}/block": { "patch": { "summary": "Block user", "tags": ["Admin"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "userid", "in": "path", "required": true, "type": "integer" }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/users/{userid}/unblock": { "patch": { "summary": "Unblock user", "tags": ["Admin"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "userid", "in": "path", "required": true, "type": "integer" }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/users/{userid}/warn": { "patch": { "summary": "Warn user", "tags": ["Admin"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "userid", "in": "path", "required": true, "type": "integer" }, { "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/ReasonRequest" } }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/users/{userid}/unwarn": { "patch": { "summary": "Remove user warning", "tags": ["Admin"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "userid", "in": "path", "required": true, "type": "integer" }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/users/{userid}/role": { "patch": { "summary": "Set user role", "tags": ["Admin"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "userid", "in": "path", "required": true, "type": "integer" }, { "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/RoleRequest" } }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/notifications": { "get": { "summary": "Get my notifications", "tags": ["Notifications"], "security": [{ "BearerAuth": [] }], "produces": ["application/json"], "responses": { "200": { "description": "Notifications" }, "401": { "description": "Unauthorized", "schema": { "$ref": "#/definitions/ErrorResponse" } } } } },
    "/api/admin/notifications": { "post": { "summary": "Create notification", "tags": ["Notifications"], "security": [{ "BearerAuth": [] }], "consumes": ["application/json"], "produces": ["application/json"], "parameters": [{ "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/NotificationRequest" } }], "responses": { "201": { "description": "Created", "schema": { "$ref": "#/definitions/MessageResponse" } }, "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } } } } },
    "/api/admin/moderation": { "get": { "summary": "Get moderation queue", "tags": ["Moderation"], "security": [{ "BearerAuth": [] }], "produces": ["application/json"], "parameters": [{ "name": "page", "in": "query", "type": "integer" }, { "name": "limit", "in": "query", "type": "integer" }], "responses": { "200": { "description": "Queue" } } } },
    "/api/admin/moderation/{transid}/approve": { "patch": { "summary": "Approve translation", "tags": ["Moderation"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "transid", "in": "path", "required": true, "type": "integer" }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/moderation/{transid}/reject": { "patch": { "summary": "Reject translation", "tags": ["Moderation"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "transid", "in": "path", "required": true, "type": "integer" }, { "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/ReasonRequest" } }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/admin/moderation/{transid}/change-status/{status}": { "patch": { "summary": "Change translation status", "tags": ["Moderation"], "security": [{ "BearerAuth": [] }], "parameters": [{ "name": "transid", "in": "path", "required": true, "type": "integer" }, { "name": "status", "in": "path", "required": true, "type": "string", "enum": ["pending_scan", "approved", "rejected", "error"] }], "responses": { "200": { "description": "OK", "schema": { "$ref": "#/definitions/MessageResponse" } } } } },
    "/api/chat/history/{userId}": { "get": { "summary": "Get chat history", "tags": ["Chat"], "security": [{ "BearerAuth": [] }], "produces": ["application/json"], "parameters": [{ "name": "userId", "in": "path", "required": true, "type": "integer" }], "responses": { "200": { "description": "Messages" } } } },
    "/api/chat/ws": { "get": { "summary": "Chat WebSocket", "tags": ["Chat"], "parameters": [{ "name": "token", "in": "query", "type": "string", "description": "JWT token for browser WebSocket clients" }], "responses": { "101": { "description": "Switching Protocols" } } } },
    "/api/internal/scan-result": { "post": { "summary": "Scanner callback", "tags": ["Internal"], "security": [{ "InternalKeyAuth": [] }], "consumes": ["application/json"], "produces": ["application/json"], "parameters": [{ "in": "body", "name": "body", "required": true, "schema": { "$ref": "#/definitions/ScanResultRequest" } }], "responses": { "200": { "description": "Accepted" }, "400": { "description": "Bad request", "schema": { "$ref": "#/definitions/ErrorResponse" } }, "403": { "description": "Forbidden", "schema": { "$ref": "#/definitions/ErrorResponse" } } } } }
  },
  "securityDefinitions": {
    "BearerAuth": { "type": "apiKey", "name": "Authorization", "in": "header", "description": "JWT token in format: Bearer <token>" },
    "InternalKeyAuth": { "type": "apiKey", "name": "X-Internal-Key", "in": "header" }
  },
  "definitions": {
    "ErrorResponse": { "type": "object", "properties": { "error": { "type": "string" } } },
    "MessageResponse": { "type": "object", "properties": { "message": { "type": "string" } } },
    "RegisterRequest": { "type": "object", "required": ["firstName", "lastName", "nickname", "password"], "properties": { "firstName": { "type": "string" }, "lastName": { "type": "string" }, "nickname": { "type": "string" }, "password": { "type": "string" } } },
    "RegisterResponse": { "type": "object", "properties": { "message": { "type": "string" }, "userId": { "type": "integer" } } },
    "LoginRequest": { "type": "object", "required": ["nickname", "password"], "properties": { "nickname": { "type": "string" }, "password": { "type": "string" } } },
    "LoginResponse": { "type": "object", "properties": { "token": { "type": "string" }, "user": { "$ref": "#/definitions/LoginUser" } } },
    "LoginUser": { "type": "object", "properties": { "id": { "type": "integer" }, "nickname": { "type": "string" }, "role": { "type": "string" } } },
    "MeResponse": { "type": "object", "properties": { "message": { "type": "string" }, "userId": { "type": "integer" }, "role": { "type": "string" } } },
    "ReasonRequest": { "type": "object", "required": ["reason"], "properties": { "reason": { "type": "string" } } },
    "RoleRequest": { "type": "object", "required": ["role"], "properties": { "role": { "type": "string", "example": "moderator", "enum": ["author", "moderator", "admin"] } } },
    "NotificationRequest": { "type": "object", "required": ["title", "message"], "properties": { "title": { "type": "string" }, "message": { "type": "string" }, "isGlobal": { "type": "boolean" }, "userId": { "type": "integer" } } },
    "GameCard": { "type": "object", "properties": { "id": { "type": "integer" }, "title": { "type": "string" }, "iconUrl": { "type": "string" }, "gameId": { "type": "integer" } } },
    "SteamGameInfo": { "type": "object", "properties": { "title": { "type": "string" }, "id": { "type": "integer", "format": "int64", "description": "Steam AppID" } } },
    "PublicGameInfo": { "type": "object", "properties": { "id": { "type": "integer" }, "title": { "type": "string" }, "iconUrl": { "type": "string" }, "steamAppId": { "type": "integer", "format": "int64" }, "steamDeckCommand": { "type": "string" }, "translations": { "type": "array", "items": { "$ref": "#/definitions/PublicTranslationSummary" } } } },
    "PublicTranslationSummary": { "type": "object", "properties": { "id": { "type": "integer" }, "authorName": { "type": "string" }, "source": { "type": "string" }, "version": { "type": "number", "format": "double" }, "percentReady": { "type": "number", "format": "double" }, "fileSize": { "type": "number", "format": "double" }, "createdAt": { "type": "string", "format": "date-time" }, "downloadUrl": { "type": "string" } } },
    "GameInfo": { "type": "object", "properties": { "id": { "type": "integer" }, "title": { "type": "string" }, "iconUrl": { "type": "string" }, "steamAppId": { "type": "integer", "format": "int64" }, "steamDeckCommand": { "type": "string" }, "translateCards": { "type": "array", "items": { "$ref": "#/definitions/TranslateCard" } } } },
    "CreateGameResponse": { "type": "object", "properties": { "message": { "type": "string" }, "title": { "type": "string" }, "big_image_url": { "type": "string" }, "small_image_url": { "type": "string" }, "gameId": { "type": "integer" }, "steamDeckCommand": { "type": "string" } } },
    "DuplicateGameResponse": { "type": "object", "properties": { "status": { "type": "string", "example": "alreadycreated" }, "gameId": { "type": "integer" }, "id": { "type": "integer" }, "title": { "type": "string" } } },
    "TranslateCard": { "type": "object", "properties": { "id": { "type": "integer" }, "authorName": { "type": "string" }, "authoreId": { "type": "integer" }, "source": { "type": "string" }, "version": { "type": "number", "format": "double" }, "percentReady": { "type": "number", "format": "double" }, "urlToDownload": { "type": "string" }, "archiveHash": { "type": "string" }, "fileSize": { "type": "number", "format": "double" }, "status": { "type": "string", "enum": ["pending_scan", "approved", "rejected", "error"] }, "scanDetails": { "type": "string" }, "gameFiles": { "type": "array", "items": { "$ref": "#/definitions/DetailedGameFile" } }, "createdAt": { "type": "string", "format": "date-time" } } },
    "CreateTranslationResponse": { "type": "object", "properties": { "message": { "type": "string" }, "urlToDownload": { "type": "string" }, "FileSize": { "type": "number", "format": "double" }, "AuthorName": { "type": "string" }, "Source": { "type": "string" }, "PercentReady": { "type": "number", "format": "double" }, "id": { "type": "integer" } } },
    "DetailedGameFile": { "type": "object", "properties": { "fileName": { "type": "string" }, "hash": { "type": "string" }, "size": { "type": "string" } } },
    "ScanResultRequest": { "type": "object", "properties": { "transId": { "type": "integer" }, "status": { "type": "string", "example": "approved", "enum": ["approved", "rejected", "error"] }, "details": { "type": "string" }, "threats": { "type": "array", "items": { "type": "string" } }, "error": { "type": "string" }, "files": { "type": "array", "items": { "$ref": "#/definitions/DetailedGameFile" } } } }
  }
}`

var SwaggerInfo = &swag.Spec{
	Version:          "1.0",
	Host:             "localhost:8080",
	BasePath:         "/",
	Schemes:          []string{"http"},
	Title:            "EasyTranslator API",
	Description:      "Backend API for EasyTranslator.",
	InfoInstanceName: "swagger",
	SwaggerTemplate:  docTemplate,
}

func init() {
	swag.Register(SwaggerInfo.InstanceName(), SwaggerInfo)
}
