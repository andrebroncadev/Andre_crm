# CRM André — Central de Operações

Aplicação web online para a operação imobiliária: relacionamento, contatos, vendas, locações, captação, imóveis, agenda, histórico, pontuação, relatórios e revisão de importações do WhatsApp.

## Produção
- Webapp: https://crm-andre.vercel.app
- Repositório: https://github.com/andrebroncadev/Andre_crm
- Hospedagem: Vercel, ligada ao GitHub
- Backend: Supabase PostgreSQL + Auth
- SDK do navegador: `@supabase/supabase-js@2.57.0` (versão fixada)

## O que já está implementado
- Autenticação por e-mail e senha.
- Workspace criado ao primeiro acesso autenticado.
- Banco online com RLS e isolamento por workspace.
- Contatos com papéis múltiplos, rank A/B/C/D/E/F/O, origem, status e confiança dos dados.
- Funis diferentes para venda, locação de temporada, locação tradicional e captação.
- R1/R2 disponíveis apenas no funil de captação.
- Imóveis com capacidade, comodidades, links de origem e confiança dos dados.
- Tarefas, retornos prometidos, histórico de atividades e notas pessoais separadas.
- Pontuação manual com categorias de atividade, resultado e ajuste; o sistema não inventa valores.
- Relatórios iniciais, backup JSON e área de staging para importação CSV/JSON.
- Log de auditoria; registros comerciais devem ser arquivados em vez de apagados.
- Tabelas com prefixo `crm_`; nenhuma tabela existente do BancoImob/Maré/Feedback Maker é sobrescrita.

## Banco de dados
Migrações versionadas em `supabase/migrations/`. As migrações iniciais já foram aplicadas ao projeto Supabase conectado. As tabelas de CRM têm Row Level Security; as notas pessoais são visíveis apenas ao usuário que as criou; o log de auditoria é append-only.

## Importação do WhatsApp
O export contém grupos e conversas pessoais além de possíveis contatos comerciais. A importação deve ser revisada antes de criar contatos e oportunidades. A análise preparada exclui grupos e inclui 307 conversas individuais com sinais lexicais comerciais; isso é uma triagem, não uma classificação confirmada. Contatos e oportunidades não devem ser considerados quentes ou fechados apenas por ausência de resposta ou por palavras-chave.

## Limitações que ainda precisam de trabalho
- O compartilhamento com membros adicionais da família/equipe precisa de uma tela de convites e configuração de membros.
- A importação de WhatsApp está em staging com aprovação manual; não importa automaticamente todo o conteúdo bruto das conversas.
- A sincronização de catálogo e disponibilidade com BancoImob/iList/Temporada Livre ainda não está ativa; BancoImob continua sendo a fonte de verdade do catálogo.
- Alertas são internos ao CRM; ainda não envia mensagens nem notificações externas.
- Backups automáticos agendados e teste de restauração precisam ser configurados.

## Segurança
Não coloque chaves secretas, service-role keys ou dados de clientes em commits. A chave publishable do Supabase usada no navegador não é uma chave administrativa; a segurança depende das políticas RLS e da autenticação.