---
name: create-report-type
description: |
  Implementa um novo tipo de relatório no sistema Meta GOB, cobrindo todos os 4 serviços
  envolvidos: report-service (migration), source-service (consumer + handler + PDF + client),
  notification-service (label), e frontend (botão de request).
  Triggers: "criar relatório", "novo tipo de relatório", "implementar relatório",
  "add report type", "new report", "criar report".
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
---

# Skill: Implementar Novo Tipo de Relatório

Cria um novo tipo de relatório assíncrono end-to-end. O sistema envolve 4 serviços e ~8 arquivos.

## Fluxo Completo

```
Frontend (botão) → POST /api/v1/reports → report-service (PENDING)
  → RabbitMQ gob.reports routing_key="report.requested"
  → source-service ReportConsumer → ReportHandler → gera PDF → upload S3
  → HTTP POST /api/v1/internal/reports/:id/complete → report-service (COMPLETED)
  → RabbitMQ gob.reports routing_key="report.completed"
  → notification-service ReportEventHandler → inbox + email|sms|whatsapp|push
  → Frontend polling (5s) → download presigned URL
```

## Pré-requisitos

Antes de começar, coletar do usuário:

| Info | Exemplo |
|------|---------|
| `report_type_key` | `merit_titles_eligibility` |
| `label` (PT-BR) | `Elegibilidade para Títulos de Mérito` |
| `description` (PT-BR) | `Análise de elegibilidade de títulos honoríficos...` |
| `source_service` | `gob-member-service` |
| `min_scope` | `LODGE`, `STATE`, `FEDERAL`, ou `MEMBER` |
| `supported_formats` | `{PDF}`, `{PDF,CSV}`, `{PDF,CSV,XLSX}` |
| Parâmetros necessários | `lodge_id`, `state_orient_id`, `year`, etc. |
| Dados fonte (query/repo) | Qual repositório/query busca os dados |

---

## Checklist Completo (4 Serviços)

### A. report-service — Migration (1 arquivo)

**Arquivo**: `services/gob-report-service/migrations/NNN_add_REPORT_KEY_report_type.up.sql`

```sql
INSERT INTO report.report_types (key, label, description, source_service, min_scope, supported_formats) VALUES
  ('REPORT_KEY', 'LABEL_PT_BR',
   'DESCRIPTION_PT_BR',
   'SOURCE_SERVICE', 'MIN_SCOPE', '{FORMATS}')
ON CONFLICT (key) DO NOTHING;
```

**Down migration** (`NNN_add_REPORT_KEY_report_type.down.sql`):
```sql
DELETE FROM report.report_types WHERE key = 'REPORT_KEY';
```

Obter o próximo número de migration:
```bash
ls services/gob-report-service/migrations/ | sort -n | tail -1
```

### B. source-service — Geração do Relatório (5-6 arquivos + main.go)

#### B1. Report Client (se ainda não existir no serviço)

**Arquivo**: `internal/client/report/client.go`

Se o serviço já tiver um report client, pular. Caso contrário, copiar o padrão:

```go
// Package report provides an HTTP client for calling the report-service internal API.
package report

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"

    "github.com/google/uuid"
)

// Client defines the interface for report-service operations.
type Client interface {
    CompleteReport(ctx context.Context, reportID uuid.UUID, storageKey, filename, contentType string, fileSize int64) error
    FailReport(ctx context.Context, reportID uuid.UUID, errorMsg string) error
}

// HTTPClient implements Client by calling gob-report-service via HTTP.
type HTTPClient struct {
    baseURL    string
    apiKey     string
    httpClient *http.Client
}

// NewHTTPClient creates a new HTTPClient that calls the report-service.
func NewHTTPClient(baseURL, apiKey string) *HTTPClient {
    return &HTTPClient{
        baseURL: baseURL,
        apiKey:  apiKey,
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
    }
}

type completeRequest struct {
    StorageKey       string `json:"storage_key"`
    OriginalFilename string `json:"original_filename"`
    ContentType      string `json:"content_type"`
    FileSize         int64  `json:"file_size"`
}

type failRequest struct {
    ErrorMessage string `json:"error_message"`
}

type errorResponse struct {
    Error string `json:"error"`
}

func (c *HTTPClient) CompleteReport(ctx context.Context, reportID uuid.UUID, storageKey, filename, contentType string, fileSize int64) error {
    body := &completeRequest{
        StorageKey:       storageKey,
        OriginalFilename: filename,
        ContentType:      contentType,
        FileSize:         fileSize,
    }

    jsonBody, err := json.Marshal(body)
    if err != nil {
        return fmt.Errorf("failed to marshal request: %w", err)
    }

    url := fmt.Sprintf("%s/api/v1/internal/reports/%s/complete", c.baseURL, reportID.String())
    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(jsonBody))
    if err != nil {
        return fmt.Errorf("failed to create request: %w", err)
    }

    req.Header.Set("Content-Type", "application/json")
    if c.apiKey != "" {
        req.Header.Set("X-Internal-Key", c.apiKey)
    }

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("failed to send request to report-service: %w", err)
    }
    defer func() { _ = resp.Body.Close() }()

    if resp.StatusCode != http.StatusOK {
        var errResp errorResponse
        if err := json.NewDecoder(resp.Body).Decode(&errResp); err == nil && errResp.Error != "" {
            return fmt.Errorf("report-service error: %s", errResp.Error)
        }
        return fmt.Errorf("report-service returned HTTP %d", resp.StatusCode)
    }

    return nil
}

func (c *HTTPClient) FailReport(ctx context.Context, reportID uuid.UUID, errorMsg string) error {
    body := &failRequest{ErrorMessage: errorMsg}

    jsonBody, err := json.Marshal(body)
    if err != nil {
        return fmt.Errorf("failed to marshal request: %w", err)
    }

    url := fmt.Sprintf("%s/api/v1/internal/reports/%s/fail", c.baseURL, reportID.String())
    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(jsonBody))
    if err != nil {
        return fmt.Errorf("failed to create request: %w", err)
    }

    req.Header.Set("Content-Type", "application/json")
    if c.apiKey != "" {
        req.Header.Set("X-Internal-Key", c.apiKey)
    }

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("failed to send request to report-service: %w", err)
    }
    defer func() { _ = resp.Body.Close() }()

    if resp.StatusCode != http.StatusOK {
        var errResp errorResponse
        if err := json.NewDecoder(resp.Body).Decode(&errResp); err == nil && errResp.Error != "" {
            return fmt.Errorf("report-service error: %s", errResp.Error)
        }
        return fmt.Errorf("report-service returned HTTP %d", resp.StatusCode)
    }

    return nil
}
```

#### B2. Report Consumer (se ainda não existir no serviço)

**Arquivo**: `internal/messaging/report_consumer.go`

```go
package messaging

import (
    "context"
    "encoding/json"
    "fmt"
    "sync"

    "github.com/gob/gob-go-commons/pkg/logger"
    amqp "github.com/rabbitmq/amqp091-go"
)

const (
    reportExchange = "gob.reports"
    reportQueue    = "gob.SOURCE_SERVICE_SHORT.reports" // e.g. "gob.member-service.reports"
    reportRouteKey = "report.requested"
)

type ReportConsumer struct {
    conn    *amqp.Connection
    channel *amqp.Channel
    handler *ReportHandler
    log     *logger.Logger
    done    chan struct{}
    wg      sync.WaitGroup
}

func NewReportConsumer(amqpURL string, handler *ReportHandler, log *logger.Logger) (*ReportConsumer, error) {
    conn, err := amqp.Dial(amqpURL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to RabbitMQ: %w", err)
    }

    ch, err := conn.Channel()
    if err != nil {
        _ = conn.Close()
        return nil, fmt.Errorf("failed to open channel: %w", err)
    }

    // QoS = 1: process one report at a time (CPU intensive)
    if err := ch.Qos(1, 0, false); err != nil {
        _ = ch.Close()
        _ = conn.Close()
        return nil, fmt.Errorf("failed to set QoS: %w", err)
    }

    if err := ch.ExchangeDeclare(reportExchange, "topic", true, false, false, false, nil); err != nil {
        _ = ch.Close()
        _ = conn.Close()
        return nil, fmt.Errorf("failed to declare exchange: %w", err)
    }

    _, err = ch.QueueDeclare(reportQueue, true, false, false, false, nil)
    if err != nil {
        _ = ch.Close()
        _ = conn.Close()
        return nil, fmt.Errorf("failed to declare queue: %w", err)
    }

    if err := ch.QueueBind(reportQueue, reportRouteKey, reportExchange, false, nil); err != nil {
        _ = ch.Close()
        _ = conn.Close()
        return nil, fmt.Errorf("failed to bind queue: %w", err)
    }

    return &ReportConsumer{
        conn: conn, channel: ch, handler: handler, log: log,
        done: make(chan struct{}),
    }, nil
}

func (c *ReportConsumer) Start(ctx context.Context) error {
    deliveries, err := c.channel.Consume(
        reportQueue,
        "SOURCE_SERVICE_SHORT-report-consumer", // e.g. "member-service-report-consumer"
        false, false, false, false, nil,
    )
    if err != nil {
        return fmt.Errorf("failed to start consuming: %w", err)
    }

    c.wg.Add(1)
    go func() {
        defer c.wg.Done()
        c.log.Info("Report consumer started")
        for {
            select {
            case <-ctx.Done():
                return
            case <-c.done:
                return
            case delivery, ok := <-deliveries:
                if !ok {
                    return
                }
                c.handleDelivery(ctx, delivery)
            }
        }
    }()

    return nil
}

func (c *ReportConsumer) Stop() {
    close(c.done)
    c.wg.Wait()
    if c.channel != nil {
        _ = c.channel.Close()
    }
    if c.conn != nil {
        _ = c.conn.Close()
    }
    c.log.Info("Report consumer stopped")
}

func (c *ReportConsumer) handleDelivery(ctx context.Context, delivery amqp.Delivery) {
    var event ReportEvent
    if err := json.Unmarshal(delivery.Body, &event); err != nil {
        c.log.WithError(err).Error("Failed to unmarshal report event")
        _ = delivery.Nack(false, false)
        return
    }

    if err := c.handler.HandleReportRequest(ctx, &event); err != nil {
        c.log.WithError(err).WithField("report_id", event.ReportID).
            Error("Failed to handle report request")
        _ = delivery.Nack(false, false)
        return
    }

    _ = delivery.Ack(false)
}
```

#### B3. Report Handler (core logic)

**Arquivo**: `internal/messaging/report_handler.go`

```go
package messaging

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/gob/gob-go-commons/pkg/logger"
    "github.com/gob/gob-go-commons/pkg/storage"
    reportclient "github.com/gob/SOURCE_SERVICE/internal/client/report"
    "github.com/gob/SOURCE_SERVICE/internal/pdf"
    "github.com/google/uuid"
)

// ReportEvent represents a report request event from the report-service.
type ReportEvent struct {
    EventID       string `json:"event_id"`
    ReportID      string `json:"report_id"`
    ReportTypeKey string `json:"report_type_key"`
    EventType     string `json:"event_type"`
    Format        string `json:"format,omitempty"`
    UserID        string `json:"user_id,omitempty"`
    UserName      string `json:"user_name,omitempty"`
    SourceService string `json:"source_service,omitempty"`
    Data          struct {
        Parameters     json.RawMessage `json:"parameters"`
        RequesterScope string          `json:"requester_scope"`
        LodgeID        interface{}     `json:"lodge_id"`
        StateOrientID  interface{}     `json:"state_orient_id"`
    } `json:"data"`
}

type ReportHandler struct {
    // Add domain-specific dependencies here (repos, services)
    store        storage.Storage
    reportClient reportclient.Client
    pdfGen       *pdf.Generator
    log          *logger.Logger
}

func NewReportHandler(
    /* domain deps, */
    store storage.Storage,
    reportClient reportclient.Client,
    log *logger.Logger,
) *ReportHandler {
    return &ReportHandler{
        store:        store,
        reportClient: reportClient,
        pdfGen:       pdf.NewGenerator(),
        log:          log,
    }
}

func (h *ReportHandler) HandleReportRequest(ctx context.Context, event *ReportEvent) error {
    // IMPORTANT: Only handle events targeted at this service
    if event.SourceService != "SOURCE_SERVICE_FULL_NAME" {
        return nil
    }

    reportID, err := uuid.Parse(event.ReportID)
    if err != nil {
        h.log.WithError(err).Error("Invalid report ID")
        return nil // ack - can't recover
    }

    h.log.WithField("report_id", event.ReportID).
        WithField("report_type", event.ReportTypeKey).
        Info("Processing report request")

    switch event.ReportTypeKey {
    case "REPORT_KEY":
        if err := h.generateReport(ctx, reportID, event); err != nil {
            h.log.WithError(err).Error("Failed to generate report")
            _ = h.reportClient.FailReport(ctx, reportID, err.Error())
            return nil // ack - already notified failure
        }
    default:
        h.log.WithField("report_type", event.ReportTypeKey).
            Warn("Unknown report type")
    }

    return nil
}

func (h *ReportHandler) generateReport(ctx context.Context, reportID uuid.UUID, event *ReportEvent) error {
    // 1. Extract parameters from event
    //    - lodge_id comes from JWT (event.Data.LodgeID) for scoped users
    //    - For federal users, it comes from event.Data.Parameters
    //    See parseLodgeID() helper below

    // 2. Fetch data from repository

    // 3. Generate PDF
    pdfBytes, err := h.pdfGen.Generate(/* data */)
    if err != nil {
        return fmt.Errorf("failed to generate PDF: %w", err)
    }

    // 4. Upload to S3
    filename := fmt.Sprintf("REPORT_FILENAME-%s.pdf", time.Now().Format("2006-01-02"))
    storageKey := storage.GenerateKey("reports", "CATEGORY", reportID, filename)

    reader := bytes.NewReader(pdfBytes)
    if _, err := h.store.Upload(ctx, storageKey, reader, int64(len(pdfBytes)), "application/pdf"); err != nil {
        return fmt.Errorf("failed to upload PDF to storage: %w", err)
    }

    // 5. Notify report-service of completion
    if err := h.reportClient.CompleteReport(ctx, reportID, storageKey, filename, "application/pdf", int64(len(pdfBytes))); err != nil {
        return fmt.Errorf("failed to notify report-service: %w", err)
    }

    h.log.WithField("report_id", reportID.String()).
        WithField("storage_key", storageKey).
        Info("Report generated successfully")

    return nil
}

// parseLodgeID extracts a UUID from the lodge_id field which may be string or nil.
func parseLodgeID(v interface{}) (*uuid.UUID, error) {
    if v == nil {
        return nil, nil
    }
    switch val := v.(type) {
    case string:
        if val == "" {
            return nil, nil
        }
        id, err := uuid.Parse(val)
        if err != nil {
            return nil, err
        }
        return &id, nil
    default:
        data, _ := json.Marshal(v)
        var s string
        if err := json.Unmarshal(data, &s); err != nil {
            return nil, fmt.Errorf("unsupported lodge_id type: %T", v)
        }
        if s == "" {
            return nil, nil
        }
        id, err := uuid.Parse(s)
        if err != nil {
            return nil, err
        }
        return &id, nil
    }
}
```

#### B4. PDF Generator

**Arquivo**: `internal/pdf/REPORT_NAME.go`

```go
package pdf

import (
    "bytes"
    "fmt"
    "time"

    "github.com/go-pdf/fpdf"
)

type ReportData struct {
    // Define the data structure for this report
    GeneratedDate time.Time
}

type Generator struct{}

func NewGenerator() *Generator {
    return &Generator{}
}

func (g *Generator) Generate(data ReportData) ([]byte, error) {
    pdf := fpdf.New("P", "mm", "A4", "")
    // IMPORTANT: cp1252 translator for Portuguese characters
    tr := pdf.UnicodeTranslatorFromDescriptor("cp1252")

    pdf.SetAutoPageBreak(true, 25)

    // Cover page
    pdf.AddPage()
    pdf.SetFont("Helvetica", "B", 10)
    pdf.SetTextColor(100, 100, 100)
    pdf.Ln(30)
    pdf.CellFormat(0, 8, tr("Grande Oriente do Brasil"), "", 1, "C", false, 0, "")

    pdf.Ln(20)
    pdf.SetFont("Helvetica", "B", 20)
    pdf.SetTextColor(0, 0, 0)
    pdf.MultiCell(0, 10, tr("REPORT_TITLE"), "", "C", false)

    pdf.Ln(10)
    pdf.SetFont("Helvetica", "", 11)
    pdf.SetTextColor(100, 100, 100)
    pdf.CellFormat(0, 8, tr(fmt.Sprintf("Gerado em %s", data.GeneratedDate.Format("02/01/2006"))), "", 1, "C", false, 0, "")

    // Content pages
    pdf.AddPage()
    // ... render report content with tr() for all Portuguese text

    // Header/Footer
    pdf.SetHeaderFuncMode(func() {
        if pdf.PageNo() > 1 {
            pdf.SetFont("Helvetica", "I", 8)
            pdf.SetTextColor(128, 128, 128)
            pdf.CellFormat(0, 5, tr("REPORT_HEADER_TEXT"), "", 0, "L", false, 0, "")
            pdf.Ln(8)
        }
    }, true)

    pdf.SetFooterFunc(func() {
        if pdf.PageNo() > 1 {
            pdf.SetY(-15)
            pdf.SetFont("Helvetica", "I", 8)
            pdf.SetTextColor(128, 128, 128)
            pdf.CellFormat(0, 10, tr(fmt.Sprintf("Página %d", pdf.PageNo())), "", 0, "C", false, 0, "")
        }
    })

    var buf bytes.Buffer
    if err := pdf.Output(&buf); err != nil {
        return nil, fmt.Errorf("failed to generate PDF: %w", err)
    }
    return buf.Bytes(), nil
}
```

#### B5. Wiring no main.go

Adicionar ao `cmd/api/main.go` do source-service:

```go
// 1. Import
import (
    reportclient "github.com/gob/SOURCE_SERVICE/internal/client/report"
    "github.com/gob/SOURCE_SERVICE/internal/messaging"
)

// 2. Initialize report client (antes do Fiber app)
var rptClient reportclient.Client
reportServiceURL := cfg.GetDefault("REPORT_SERVICE_URL", "")
if reportServiceURL != "" {
    internalKey := cfg.GetDefault("INTERNAL_API_KEY", "")
    if internalKey == "" {
        internalKey = cfg.GetDefault("SHARED_INTERNAL_API_KEY", "")
    }
    rptClient = reportclient.NewHTTPClient(reportServiceURL, internalKey)
    log.Info("Report client initialized")
}

// 3. Initialize report consumer (antes do Fiber app)
var reportConsumer *messaging.ReportConsumer
if rptClient != nil {
    if rmqURL := cfg.GetDefault("RABBITMQ_URL", ""); rmqURL != "" {
        reportHandler := messaging.NewReportHandler(/* domain deps, */ store, rptClient, log)
        rc, rcErr := messaging.NewReportConsumer(rmqURL, reportHandler, log)
        if rcErr != nil {
            log.WithError(rcErr).Warn("Failed to initialize report consumer")
        } else {
            reportConsumer = rc
            reportCtx, reportCancel := context.WithCancel(context.Background())
            if startErr := reportConsumer.Start(reportCtx); startErr != nil {
                log.WithError(startErr).Warn("Failed to start report consumer")
                reportCancel()
            } else {
                defer reportCancel()
                defer reportConsumer.Stop()
                log.Info("Report consumer started")
            }
        }
    }
}
```

#### B6. ETCD Config

Setar no ETCD do source-service:

```bash
# Dev (docker ETCD)
etcdctl put /gob/SOURCE_SERVICE/REPORT_SERVICE_URL "http://localhost:3015"

# Prod
etcdctl put /gob/SOURCE_SERVICE/REPORT_SERVICE_URL "http://localhost:8015"
```

### C. notification-service — Label do Relatório (1 edição)

**Arquivo**: `services/gob-notification-service/internal/messaging/report_handler.go`

Adicionar o label ao map `reportTypeLabel()`:

```go
func (h *ReportEventHandler) reportTypeLabel(key string) string {
    labels := map[string]string{
        // ... existing labels ...
        "REPORT_KEY": "LABEL_PT_BR",  // <-- adicionar
    }
    // ...
}
```

**Nota**: O handler generico de report.completed/report.failed ja funciona para qualquer tipo. Nao precisa de migration nem template novo. Apenas adicionar o label para a mensagem ficar bonita no inbox.

### D. Frontend — Botao de Request (1-2 arquivos)

**Arquivo**: Na pagina que faz sentido para o relatorio (ex: lodge-detail, member-list, etc.)

```tsx
import { useRequestReport } from '@/features/reports';

// Dentro do componente:
const requestReport = useRequestReport();

// No JSX:
<Button
  variant="outline"
  size="sm"
  disabled={requestReport.isPending}
  onClick={() => requestReport.mutate({
    report_type_key: 'REPORT_KEY',
    format: 'PDF',
    parameters: { /* parametros extras, ex: lodge_id */ },
  })}
>
  <FileText className="mr-2 h-4 w-4" />
  {requestReport.isPending ? 'Solicitando...' : 'BUTTON_LABEL'}
</Button>
```

**Importante sobre `parameters`**: Para relatórios scoped (ex: LODGE), o `lodge_id` e `state_orient_id` vêm automaticamente do JWT do usuário. Mas se um usuário federal precisa gerar o relatório para uma loja específica, o `lodge_id` deve ser enviado em `parameters`. O handler no source-service faz o fallback:
1. Primeiro tenta `event.Data.LodgeID` (do JWT)
2. Se nil, tenta `event.Data.Parameters.lodge_id` (do frontend)

---

## Gotchas (Armadilhas Comuns)

### 1. lodge_id para usuarios federal
O `event.Data.LodgeID` vem do JWT claims. Para usuarios federais, este campo e nil. O `lodge_id` precisa vir de `parameters` (enviado pelo frontend). O handler DEVE fazer fallback:
```go
lodgeID, _ := parseLodgeID(event.Data.LodgeID)
if lodgeID == nil && len(event.Data.Parameters) > 0 {
    var params map[string]interface{}
    if err := json.Unmarshal(event.Data.Parameters, &params); err == nil {
        if v, ok := params["lodge_id"]; ok {
            lodgeID, _ = parseLodgeID(v)
        }
    }
}
```

### 2. storage.GenerateKey recebe uuid.UUID, nao string
```go
// CORRETO:
storageKey := storage.GenerateKey("reports", "members", reportID, filename)
// reportID e do tipo uuid.UUID

// ERRADO:
storageKey := storage.GenerateKey("reports", "members", event.ReportID, filename)
// event.ReportID e string
```

### 3. storage.Upload retorna (*FileInfo, error)
```go
// CORRETO:
if _, err := h.store.Upload(ctx, storageKey, reader, int64(len(pdfBytes)), "application/pdf"); err != nil {

// ERRADO (ignora FileInfo return):
if err := h.store.Upload(ctx, ...); err != nil {
```

### 4. fpdf precisa de CP1252 para portugues
```go
tr := pdf.UnicodeTranslatorFromDescriptor("cp1252")
// Usar tr() em TODA string com acentos
pdf.CellFormat(0, 8, tr("Relatório de Elegibilidade"), ...)
```
Sem o `tr()`, acentos aparecem como lixo no PDF.

### 5. Import cycle: usar interface no package messaging
Se o handler precisa chamar um method do service (ex: `CheckEligibility`), definir uma interface no package `messaging` para quebrar o ciclo:
```go
// messaging/report_handler.go
type EligibilityChecker interface {
    CheckMeritTitleEligibility(ctx context.Context, memberID uuid.UUID) ([]domain.MeritTitleEligibility, error)
}
```
O service implementa a interface. O main.go injeta o service como a interface.

### 6. source_service filter e obrigatorio
Todo handler DEVE filtrar por source_service no inicio:
```go
if event.SourceService != "gob-XXXXX-service" {
    return nil // silently ignore events for other services
}
```
Todos os source-services recebem TODOS os `report.requested` events. Sem o filtro, um serviço tentaria gerar relatórios de outro.

### 7. Nack sem requeue apos fail
Quando o handler chama `FailReport()`, deve fazer `delivery.Nack(false, false)` (sem requeue). Caso contrario, o evento fica em loop infinito.

### 8. go.sum e go mod tidy
Apos adicionar dependencias (fpdf, amqp, etc.):
```bash
cd services/SOURCE_SERVICE && go mod tidy
```

---

## Deploy e Verificacao

### 1. Rodar migrations
```bash
# Dev
make migrate-up SERVICE=gob-report-service

# Prod
./scripts/migrate.sh --service=gob-report-service up
```

### 2. Setar ETCD (se novo source-service)
```bash
# Prod
ssh root@meta.gob.org.br
etcdctl put /gob/SOURCE_SERVICE/REPORT_SERVICE_URL "http://localhost:8015"
```

### 3. Deploy source-service
```bash
make deploy SERVICE=SOURCE_SERVICE
```

### 4. Verificacao end-to-end

1. **Migration**: Verificar que o tipo aparece em `GET /api/v1/reports/types`
2. **Request**: Criar relatorio via frontend ou curl:
   ```bash
   curl -X POST https://api.gob.localhost/api/v1/reports \
     -H "Authorization: Bearer TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"report_type_key":"REPORT_KEY","format":"PDF","parameters":{}}'
   ```
3. **Consumer**: Verificar log do source-service: `"Processing report request"`
4. **PDF**: Verificar log: `"Report generated successfully"` com `storage_key`
5. **Completion**: Verificar status COMPLETED em `GET /api/v1/reports/:id`
6. **Notification**: Verificar inbox notification na UI
7. **Download**: Clicar download na pagina `/my-reports`

### 5. Rollback
Se algo der errado:
```bash
# Reverter migration
./scripts/migrate.sh --service=gob-report-service down 1
```

---

## Resumo de Arquivos por Servico

| # | Servico | Arquivo | Acao |
|---|---------|---------|------|
| 1 | report-service | `migrations/NNN_*.up.sql` | Criar |
| 2 | report-service | `migrations/NNN_*.down.sql` | Criar |
| 3 | source-service | `internal/client/report/client.go` | Criar (se nao existe) |
| 4 | source-service | `internal/messaging/report_consumer.go` | Criar (se nao existe) |
| 5 | source-service | `internal/messaging/report_handler.go` | Criar ou editar (add case) |
| 6 | source-service | `internal/pdf/REPORT_NAME.go` | Criar |
| 7 | source-service | `cmd/api/main.go` | Editar (wiring) |
| 8 | notification-service | `internal/messaging/report_handler.go` | Editar (add label) |
| 9 | frontend | Pagina relevante (ex: `lodge-detail.tsx`) | Editar (add botao) |

**Total**: ~9 touchpoints, 4 servicos.