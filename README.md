# Query - ga4_session_atribution_history: Query para Atribuição de Fonte de Tráfego com Janela de 90 Dias
## Descrição
Esta query realiza uma atribuição detalhada das fontes de tráfego para sessões de usuários, utilizando uma janela de 90 dias. O objetivo é identificar a primeira e última fonte de tráfego de cada sessão e, em seguida, aplicar a atribuição last non-direct click (LNDC), atribuindo o tráfego da sessão a uma fonte não direta dentro da janela de 90 dias. Ela processa dados de eventos para determinar as origens das sessões do usuário com base em fontes de tráfego coletadas via eventos. Deve ser utilizada em dados históricos anteriores a criação dos campos nativos de atribuição last_click. 

## Estrutura
**1- analysis_period:** Define o período de análise, que neste exemplo está configurado para o mês de abril de 2024.

**2- raw_events_data:** Extrai dados brutos de eventos, incluindo informações sobre o dispositivo, ID de sessão, fontes de tráfego coletadas manualmente e o gclid.

**3- trusted_events:** Prepara os dados, atribuindo valores de utm_source, utm_medium e utm_campaign com base na presença de gclid e na configuração das campanhas.

**4- session_traffic_sources:** Agrupa os eventos por sessão, identificando a primeira e a última fonte de tráfego em cada sessão.

**5- last_non_direct_click_attribution:** Aplica a lógica de atribuição LNDC dentro de uma janela de 90 dias, determinando a fonte de tráfego atribuída para cada sessão.

**6- validated_source_attribution:** Valida e finaliza a atribuição das fontes de tráfego, preparando os dados para a análise final.

## Instruções
**1- Ambiente de Execução:** Certifique-se de que você está utilizando um ambiente que suporte SQL ANSI, como BigQuery, onde a query foi projetada para ser executada.

**2- Configuração do Período de Análise:** O período de análise pode ser ajustado modificando as datas de início e fim na CTE analysis_period.

**3- Dataset:** Atualize o dataset na CTE raw_events_data conforme necessário para apontar para o seu conjunto de dados específico.

**4- Execução:** Execute a query em seu ambiente de análise para gerar os dados de atribuição.

## Observações
- Certifique-se de que as colunas e tabelas referenciadas na query correspondam à sua estrutura de dados.
- Esta query utiliza funções avançadas, como ARRAY_AGG e window functions, que devem ser suportadas pelo seu sistema SQL.
- Revise e teste a query cuidadosamente para assegurar a precisão dos resultados.


# Query - ga4_session_atribution: Query de Análise de Dados de GA4
## Descrição
Esta query é utilizada para carregar e processar dados de eventos do Google Analytics 4 (GA4). Ela formata e categoriza dados de tráfego, eventos e transações para análise detalhada, facilitando a geração de insights sobre o comportamento do usuário e a eficácia de campanhas.

## Estrutura
**1- ga4_fresh_table:** Esta CTE (Common Table Expression) carrega dados da tabela do GA4, transformando datas e horários, e extraindo informações relevantes, como o nome do evento, categoria do dispositivo, ID do usuário e fontes de tráfego.

**2- raw_data:** Nesta etapa, os dados carregados são refinados. A query converte datas, ajusta o fuso horário e identifica eventos de compra, atribuindo o transaction_id apenas para eventos confirmados como "purchase" e com ID válido.

**3- set_referral:** Aqui, os dados de tráfego são categorizados e tratados. Fontes de tráfego conhecidas, como "google" e "bing", são classificadas como "cpc" quando apropriado. A query também trata casos onde os campos de fonte ou meio de tráfego estão marcados como "(not set)", substituindo-os por "(direct)" e "(none)" respectivamente.

**4- Consulta Final:** Esta última parte agrega os dados processados, calculando métricas chave:

- Sessions: Número de sessões distintas por usuário e ID de sessão.
- Total Users: Total de usuários únicos.
- Transactions: Número de transações realizadas.
- Conversion Rate: Taxa de conversão calculada dividindo o número de transações pelo número de sessões.
- Revenue: Receita total gerada pelas transações.

# Instruções
**1- Ambiente de Execução:** Certifique-se de que está usando uma plataforma que suporta SQL ANSI, como o BigQuery.

**2- Configuração do Dataset:** Atualize a referência do dataset na CTE ga4_fresh_table para apontar para o seu conjunto de dados.

**3- Filtragem de Datas:** A filtragem por datas está comentada na query. Descomente e ajuste o filtro conforme necessário para selecionar o intervalo de datas desejado.

**4- Execução:** Execute a query em seu ambiente SQL para processar e analisar os dados do GA4.

# Observações
- Validação: Verifique se as colunas e tabelas referenciadas correspondem à sua estrutura de dados específica.
- Ajustes Necessários: Personalize a query para atender aos requisitos do seu projeto, especialmente no que diz respeito às fontes e meios de tráfego.