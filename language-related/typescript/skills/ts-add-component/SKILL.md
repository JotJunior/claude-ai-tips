---
name: ts-add-component
description: |
  Use quando o usuário disser "add component", "novo componente", "criar component react", "add shadcn", "novo shadcn component", "criar UI component", "React component", "criar button", "criar input", "criar card", "criar modal", "criar form"
  Também quando mencionar "shadcn/ui", "radix-ui", "criar componente", "build component", "React component com types"
  NAO use quando for criar rota de API backend (use ts-add-route) ou domínio DDD completo (use ts-add-domain).
allowed-tools: [Read, Write, Glob, Grep]
---

# Criar Componente React com shadcn/ui + Tailwind + Design Tokens

## Intro

Cria um componente React tipado usando a estrutura shadcn/ui como base, estilizado com Tailwind CSS através da utilidade `cn()` (classnames utility), com props tipadas via Zod schema opcional e suporte a ref forwarding. Componentes são criados em `src/components/` com Storybook file opcional. Design tokens são usados via CSS custom properties (`--color-*`, `--spacing-*`).

## Trigger Phrases

- "add component"
- "novo componente"
- "criar component react"
- "add shadcn"
- "novo shadcn component"
- "criar UI component"
- "React component"
- "criar button"
- "criar input"
- "criar card"
- "criar modal"
- "criar form"
- "shadcn/ui"
- "radix-ui"
- "criar componente"
- "build component"

## Pre-flight Reads

1. **`/components.json`** — Confirmar path de components, estilo de nomenclatura (PascalCase), e se já existe a pasta de components.
2. **`/tailwind.config.ts`** — Verificar `content` paths, extensiones de theme (design tokens), e como colors/text-sizes/spacing estão configurados.
3. **`/src/lib/utils.ts`** — Verificar se `cn()` (clsx + tailwind-merge) já existe. Se não, criar (obrigatório para shadcn).
4. **`/src/lib/tokens.ts`** ou **`/src/styles/tokens.css`** — Identificar design tokens disponíveis (cores, spacing, border-radius, shadows).
5. **`/src/components/ui/`** — Listar componentes shadcn existentes para usar como referência de estrutura (props, estilo de export).

## Workflow

1. **Definir nome e props do componente** — Nome em PascalCase (ex: `DataTable`, `UserCard`). Props como interface TypeScript. Props opcionais com `?`.
2. **Criar arquivo em `/src/components/<Name>.tsx`** — Estrutura: imports (React, cn, types), interface Props, componente funcional com `forwardRef` se precisar de ref (ex: input, button).
3. **Usar `cn()` para classes condicionais** — Classes Tailwind condicionais passam por `cn()`: `cn("base-class", condition && "conditional-class", className)`. Nunca usar template literals de string com vários ternários.
4. **Aplicar design tokens via CSS vars** — Usar `var(--token-name)` em vez de valores hardcoded: `backgroundColor: "var(--color-primary)"`, `padding: "var(--spacing-4)"`.
5. **Importar componente no destino** — Atualizar imports do arquivo que consome o componente. Evitar re-exports múltiplos.
6. **Criar Story file opcional** — `src/components/<Name>.stories.tsx` com Variant column (default, hover, disabled, etc.) e Args.
7. **Registrar no index se existir** — Se há `src/components/index.ts`, adicionar export. Caso contrário, imports diretos.

## Exemplos

### Bom — Button component com variant, size, ref forwarding

```typescript
// src/components/ui/Button.tsx
import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'outline' | 'ghost' | 'destructive';
  size?: 'sm' | 'md' | 'lg' | 'icon';
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'md', asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        className={cn(
          'inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
          'disabled:pointer-events-none disabled:opacity-50',
          variantStyles[variant],
          sizeStyles[size],
          className,
        )}
        ref={ref}
        {...props}
      />
    );
  },
);
Button.displayName = 'Button';

const variantStyles = {
  default: 'bg-[var(--color-primary)] text-[var(--color-on-primary)] hover:bg-[var(--color-primary-hover)]',
  outline: 'border-2 border-[var(--color-border)] bg-transparent hover:bg-[var(--color-muted)]',
  ghost: 'hover:bg-[var(--color-muted)]',
  destructive: 'bg-[var(--color-destructive)] text-white hover:bg-[var(--color-destructive-hover)]',
};

const sizeStyles = {
  sm: 'h-9 px-3 text-sm',
  md: 'h-10 px-4 text-base',
  lg: 'h-12 px-6 text-lg',
  icon: 'h-10 w-10',
};

export { Button };
export type { ButtonProps };
```

```typescript
// src/components/UserCard.tsx
import * as React from 'react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/Button';

interface UserCardProps {
  name: string;
  email: string;
  role?: 'admin' | 'user';
  onEdit?: () => void;
  className?: string;
}

export function UserCard({ name, email, role = 'user', onEdit, className }: UserCardProps) {
  return (
    <div
      className={cn(
        'flex flex-col gap-3 rounded-lg border p-4',
        'bg-[var(--color-surface)] border-[var(--color-border)]',
        className,
      )}
    >
      <div>
        <p className="text-[var(--text-primary)] font-semibold">{name}</p>
        <p className="text-[var(--text-muted)] text-sm">{email}</p>
      </div>
      <div className="flex items-center justify-between">
        <span
          className={cn(
            'rounded-full px-2 py-0.5 text-xs font-medium',
            role === 'admin'
              ? 'bg-[var(--color-primary)] text-[var(--color-on-primary)]'
              : 'bg-[var(--color-muted)] text-[var(--text-muted)]',
          )}
        >
          {role}
        </span>
        <Button variant="outline" size="sm" onClick={onEdit}>
          Editar
        </Button>
      </div>
    </div>
  );
}
```

```typescript
// src/components/UserCard.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { UserCard } from './UserCard';

const meta: Meta<typeof UserCard> = {
  component: UserCard,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof UserCard>;

export const Default: Story = {
  args: { name: 'João Silva', email: 'joao@exemplo.com', role: 'user' },
};

export const Admin: Story = {
  args: { name: 'Admin Sistema', email: 'admin@exemplo.com', role: 'admin' },
};

export const WithEditCallback: Story = {
  args: { name: 'Teste', email: 'teste@exemplo.com', onEdit: () => alert('Edit clicked') },
};
```

### Ruim — style inline, cn() ausente, sem tipagem de props

```tsx
// RUIM: Style inline (impossível usar design tokens, impossibilita dark mode)
<div style={{ backgroundColor: '#007bff', padding: '16px' }}>...</div>

// RUIM: Sem cn(), classes condicionais em template literal
<div className={`base-class ${isActive && 'active-class'} ${className}`}>
// Isso funciona mas não faz merge de Tailwind classes duplicadas corretamente.

// RUIM: Props sem interface, usando any
function UserCard({ name, email, onEdit }) { // any implícito para onEdit
  return <div>{name}</div>;
}

// RUIM: Sem forwardRef em componente que precisa de ref
function Input({ ...props }) {
  return <input {...props} />; // não consegue receber ref do pai
}

// RUIM: Variantes hardcoded sem map
<div className={
  variant === 'primary' ? 'bg-blue-500 text-white px-4 py-2' :
  variant === 'secondary' ? 'bg-gray-200 text-black px-4 py-2' :
  //... isso não escala
} />
```

## Gotchas

1. **`cn()` utility é crucial** — `cn()` (clsx + tailwind-merge) faz merge correto de classes Tailwind, especialmente quando subclasses conflitantes são passadas. Sem ele, `className` do consumer pode sobrescrever variantes unexpectedly. Instale: `npm install clsx tailwind-merge`.

2. **Evitar style inline** — Styles inline não participam do Tailwind purge, não respondem a design tokens CSS vars, e impossibilitam dark mode. Sempre use classes Tailwind ou CSS custom properties (`var(--token)`).

3. **Design tokens via CSS vars** — Definir tokens em `tokens.css` como `--color-primary: #007bff` permite que o tema (dark mode) altere todos os componentes simultaneamente alterando apenas os valores das vars no `:root` ou `[data-theme="dark"]`.

4. **Ref forwarding com `forwardRef`** — Qualquer componente que precise receber uma ref (custom inputs, wrappers de elementos nativos, componentes que simulam Tags/Button/etc.) deve usar `React.forwardRef`. Sempre definir `displayName` após `forwardRef` para debug no React DevTools.

5. **Zod schema para props complexas** — Se o componente tem props com lógica de validação (ex: um DatePicker que recebe `minDate`, `maxDate`), considerar exportar um Zod schema junto. Usar `z.object` para tipar props de forma explícita e permitir validação em runtime.

6. **Composição com Slot do Radix** — Para componentes que precisam renderizar children externos (ex: um wrapper que recebe qualquer JSX), usar `@radix-ui/react-slot` com `asChild`. Isso permite que o componente pai controle o elemento raiz real, mantendo ref forwarding e event handlers corretos.
