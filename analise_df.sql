-- Eleições 2026: Perfil do Eleitorado do Distrito Federal
-- Fonte: TSE, Portal de Dados Abertos (perfil_eleitor_secao_2026_DF, gerado em 14/07/2026)
-- Esse é o eleitorado oficial da eleição de 04/10/2026, porque o cadastro eleitoral fecha uns 150 dias antes da eleição
-- Objetivo: entender quem são os eleitores do DF e onde eles estão (zona, seção e escola),
-- pensando em perguntas de políticas públicas: desigualdade de escolaridade, voto facultativo e acessibilidade
--
-- Antes de tudo, uma coisa importante sobre essa tabela:
-- cada linha NÃO é uma pessoa, é um grupo de eleitores com o mesmo perfil na mesma seção
-- e.g. "30 mulheres casadas, de 40 a 44 anos, com ensino médio, na seção 225"
-- então para contar pessoas eu sempre uso SUM(qt_eleitores) e nunca COUNT(*), que só conta linhas


-- PARTE 1: EXPLORAÇÃO DOS DADOS

-- 1. VISÃO GERAL: TOTAL DE ELEITORES, ZONAS E SEÇÕES
-- Primeiro eu quis ver o tamanho do eleitorado e como ele está dividido
-- Uma seção só é única junto com a zona (a seção 225 existe em várias zonas), por isso eu juntei as duas para contar
SELECT SUM(qt_eleitores) AS total_eleitores,
       COUNT(DISTINCT nr_zona) AS zonas,
       COUNT(DISTINCT nr_zona || '-' || nr_secao) AS secoes
FROM perfil_eleitorado; -- 2.253.132 eleitores, 19 zonas e 7.042 seções

-- 2. ELEITORES POR GÊNERO
-- Para calcular o percentual, eu divido o total de cada gênero pelo total geral do DF (a subquery dentro do ROUND)
SELECT genero,
       SUM(qt_eleitores) AS eleitores,
       ROUND(100.0 * SUM(qt_eleitores) / (SELECT SUM(qt_eleitores) FROM perfil_eleitorado), 1) AS perc
FROM perfil_eleitorado
GROUP BY genero
ORDER BY eleitores DESC; -- 54,1% mulheres e 45,9% homens
-- Esse percentual é quase o mesmo em todas as zonas, então gênero não ajuda a comparar regiões

-- 3. ELEITORES POR ESCOLARIDADE
-- Eu ordenei pelo código (cd_escolaridade) e não pelo texto, para os níveis aparecerem em ordem, do analfabeto ao superior completo
SELECT escolaridade,
       SUM(qt_eleitores) AS eleitores,
       ROUND(100.0 * SUM(qt_eleitores) / (SELECT SUM(qt_eleitores) FROM perfil_eleitorado), 1) AS perc
FROM perfil_eleitorado
GROUP BY cd_escolaridade, escolaridade
ORDER BY cd_escolaridade; -- o grupo maior é ensino médio completo (30,7%), seguido de superior completo (23,3%)

-- 4. PERCENTUAL COM ENSINO SUPERIOR COMPLETO POR ZONA
-- Aqui eu queria saber se a escolaridade muda muito de uma região para outra
-- O CASE WHEN olha linha por linha: se a pessoa tem superior completo, soma os eleitores daquela linha, se não, soma 0
SELECT nr_zona,
       SUM(qt_eleitores) AS eleitores,
       ROUND(100.0 * SUM(CASE WHEN escolaridade = 'SUPERIOR COMPLETO' THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_superior
FROM perfil_eleitorado
GROUP BY nr_zona
ORDER BY perc_superior DESC; -- muda muito: de 58,5% na zona 1 (Asa Sul) até 7,2% na zona 21 (Recanto das Emas e Samambaia)
-- Por isso escolaridade virou a variável principal do projeto

-- 5. ESCOLARIDADE POR FAIXA DE IDADE
-- O TSE tem mais de 20 faixas de idade, então eu juntei em 4 grupos para ficar mais fácil de ler
-- Coloquei um número na frente de cada grupo ('1.', '2.'...) para eles aparecerem na ordem certa no ORDER BY
SELECT CASE
         WHEN cd_faixa_etaria < 2500 THEN '1. 16 a 24'
         WHEN cd_faixa_etaria < 4000 THEN '2. 25 a 39'
         WHEN cd_faixa_etaria < 6000 THEN '3. 40 a 59'
         ELSE '4. 60+'
       END AS grupo_idade,
       SUM(qt_eleitores) AS eleitores,
       ROUND(100.0 * SUM(CASE WHEN escolaridade = 'SUPERIOR COMPLETO' THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_superior,
       ROUND(100.0 * SUM(CASE WHEN cd_escolaridade BETWEEN 1 AND 3 THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_ate_fund_incompleto
FROM perfil_eleitorado
WHERE cd_faixa_etaria > 0 -- tira a faixa 'Inválida' (código -3), ver consulta 7
GROUP BY grupo_idade
ORDER BY grupo_idade; -- quase 1 em cada 3 eleitores com 60+ não completou o ensino fundamental (31%)
-- O grupo de 16 a 24 tem só 1,4% com superior, mas é normal, a maioria ainda não teve tempo de terminar a faculdade

-- 6. QUALIDADE DOS DADOS: QUANTO DA COLUNA RAÇA/COR ESTÁ VAZIA?
-- Eu queria usar raça/cor na análise, então antes conferi se a coluna está preenchida
SELECT raca_cor,
       ROUND(100.0 * SUM(qt_eleitores) / (SELECT SUM(qt_eleitores) FROM perfil_eleitorado), 1) AS perc
FROM perfil_eleitorado
GROUP BY raca_cor
ORDER BY perc DESC; -- 83,1% 'NÃO INFORMADO'
-- Com tanta coisa faltando, eu decidi NÃO usar raça/cor nas comparações, o resultado não seria confiável
-- Mas isso também é um achado: falta de dado sobre raça atrapalha políticas de igualdade racial


-- PARTE 2: LIMPEZA DOS DADOS

-- 7. PROCURANDO VALORES ESTRANHOS
-- Na consulta 5 eu vi que existe uma faixa de idade 'Inválida', então fui ver quantos eleitores tem nela
SELECT COUNT(*) AS linhas,
       SUM(qt_eleitores) AS eleitores
FROM perfil_eleitorado
WHERE faixa_etaria = 'Inválida'; -- 7 eleitores com faixa etária 'Inválida' (0,0003%): removidos das análises por idade
-- Eu pensei em apagar essas linhas com DELETE, mas preferi não apagar:
-- só a idade está errada, o gênero e a escolaridade dessas pessoas estão certos
-- Se eu apagasse, elas sumiriam das outras análises e o total não bateria mais com o número oficial do TSE
-- Então mantive na tabela e só tirei com WHERE quando a análise é por idade

-- Depois fiz o mesmo com o gênero
SELECT COUNT(*) AS linhas,
       SUM(qt_eleitores) AS genero_nao_informado
FROM perfil_eleitorado
WHERE genero = 'NÃO INFORMADO'; -- 5 eleitores com gênero 'NÃO INFORMADO': excluídos apenas das análises por gênero
-- Os dados do TSE vieram bem limpos (sem vazios e sem eleitores negativos). O único problema grande é a raça/cor, com 83% "não informado", e isso vimos na consulta 6.

-- 8. TOTAL DE ELEITORES POR SEÇÃO
-- Até aqui cada seção aparecia em várias linhas, uma para cada perfil
-- Agrupando por zona e seção, eu fico com uma linha por seção
SELECT nr_zona,
       nr_secao,
       SUM(qt_eleitores) AS total_eleitores
FROM perfil_eleitorado
GROUP BY nr_secao, nr_zona
ORDER BY total_eleitores DESC; -- a maior seção é a 455 da zona 2, com 413 eleitores. A média é de 320 por seção

-- 9. PERCENTUAL COM ENSINO SUPERIOR COMPLETO POR SEÇÃO
-- Mesma lógica da consulta 4, só que agora por seção, que é um nível bem mais detalhado que a zona
SELECT nr_zona,
       nr_secao,
       SUM(qt_eleitores) AS total_eleitores,
       ROUND(100.0 * SUM(CASE WHEN escolaridade = 'SUPERIOR COMPLETO' THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_superior
FROM perfil_eleitorado
GROUP BY nr_zona, nr_secao
ORDER BY perc_superior DESC;
-- O 1º lugar tem 100%, mas olhando melhor a seção tem só 1 eleitor, então esse número não quer dizer nada
-- Tirando esse caso, o topo é quase todo da zona 11, com 77% a 83% de ensino superior

-- 10. SEÇÕES PEQUENAS QUE DISTORCEM OS PERCENTUAIS
-- Depois do que eu vi na consulta 9, fui procurar quantas seções são pequenas demais
-- Aqui uso HAVING e não WHERE, porque eu quero filtrar pelo total da seção (depois do GROUP BY), e não linha por linha
SELECT nr_zona,
       nr_secao,
       SUM(qt_eleitores) AS total_eleitores
FROM perfil_eleitorado
GROUP BY nr_zona, nr_secao
HAVING SUM(qt_eleitores) < 50
ORDER BY total_eleitores; -- 13 seções com menos de 50 eleitores (0,2% das seções): mantidas nos totais,
-- excluídas das comparações de % por seção, pois amostras pequenas geram % extremos (0% ou 100%)
-- Escolhi o limite de 50 porque uma seção normal tem uns 320 eleitores, então menos de 50 está bem fora do padrão


-- PARTE 3: A VIEW POR SEÇÃO

-- 11. VIEW POR SEÇÃO: UMA LINHA POR SEÇÃO, BASE PARA O TABLEAU
-- Eu criei uma view para não mandar os dados crus para o Tableau:
-- a tabela original tem 1,2 milhão de linhas e a view tem 7.042 (uma por seção)
-- e os percentuais já saem calculados e conferidos aqui no SQL, sem risco de errar a conta de novo no Tableau
CREATE VIEW perfil_por_secao AS
SELECT nr_zona,
       nr_secao,
       SUM(qt_eleitores) AS total_eleitores,
       ROUND(100.0 * SUM(CASE WHEN escolaridade = 'SUPERIOR COMPLETO' THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_superior
FROM perfil_eleitorado
GROUP BY nr_zona, nr_secao;


-- 12. RECRIA A VIEW POR SEÇÃO COM VOTO FACULTATIVO, ANALFABETOS, DEFICIÊNCIA E NOME DA ESCOLA
-- Depois eu quis acrescentar mais colunas. Uma view não muda depois de criada, então primeiro eu apago e depois crio de novo
-- Voto facultativo: quem tem 16 ou 17 anos, 70 anos ou mais, ou é analfabeto não é obrigado a votar
-- Para deficiência eu não precisei de CASE WHEN, porque a coluna qt_deficiencia já diz quantas pessoas de cada linha têm deficiência
-- Cada seção fica em uma escola só, por isso dá para colocar o nome da escola no GROUP BY sem mudar o número de linhas
DROP VIEW perfil_por_secao;

CREATE VIEW perfil_por_secao AS
SELECT nr_zona,
       nr_secao,
       nm_local_votacao,
       SUM(qt_eleitores) AS total_eleitores,
       ROUND(100.0 * SUM(CASE WHEN escolaridade = 'SUPERIOR COMPLETO' THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_superior,
       ROUND(100.0 * SUM(CASE WHEN cd_faixa_etaria IN (1600, 1700) THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_16_17,
       ROUND(100.0 * SUM(CASE WHEN cd_faixa_etaria >= 7074 THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_70_mais,
       ROUND(100.0 * SUM(CASE WHEN cd_escolaridade = 1 THEN qt_eleitores ELSE 0 END)
             / SUM(qt_eleitores), 1) AS perc_analfabeto,
       ROUND(100.0 * SUM(qt_deficiencia)
             / SUM(qt_eleitores), 1) AS perc_deficiencia
FROM perfil_eleitorado
GROUP BY nr_zona, nr_secao, nm_local_votacao;

-- Testando a view
SELECT * FROM perfil_por_secao ORDER BY perc_deficiencia DESC;
-- Tirando a seção com 1 eleitor, o topo é o Centro de Ensino Especial 01 (zona 6), com 9,4% de eleitores com deficiência
-- A média do DF é de 1%. Faz sentido: uma escola de educação especial já tem estrutura de acessibilidade
-- Também testei ordenando por perc_70_mais: o topo é a Escola Classe 01 SHI Sul, no Lago Sul, com 36,5% de eleitores com 70+


-- PARTE 4: ANÁLISE AVANÇADA

-- 13. RANKING DAS ZONAS POR PERCENTUAL DE ENSINO SUPERIOR
-- Aqui eu uso a view para juntar as seções por zona e dar uma posição para cada zona com RANK()
-- Para juntar os percentuais das seções eu não podia usar uma média simples, senão uma seção com 1 eleitor pesaria igual a uma com 400
-- Então fiz uma média ponderada: cada percentual multiplicado pelo número de eleitores da seção
-- Dentro do OVER eu repeti a conta inteira, porque se eu escrevesse só perc_superior o SQLite usaria a coluna da view
-- (o percentual de uma seção qualquer da zona) e não o percentual da zona, e o ranking ficaria errado
SELECT nr_zona,
       SUM(total_eleitores) AS eleitores,
       ROUND(SUM(perc_superior * total_eleitores) / SUM(total_eleitores), 1) AS perc_superior,
       RANK() OVER (ORDER BY SUM(perc_superior * total_eleitores) / SUM(total_eleitores) DESC) AS ranking
FROM perfil_por_secao
GROUP BY nr_zona; -- 1º lugar: zona 1 (58,5%). Último: zona 21 (7,2%). Uma diferença de 8 vezes dentro da mesma cidade
-- As zonas 3 e 2 aparecem as duas com 20,1%, mas não empatam no ranking porque o ROUND esconde as outras casas decimais


-- 14. SEÇÕES DIVIDIDAS EM 4 GRUPOS (QUARTIS) DE ESCOLARIDADE
-- Agora eu quis comparar o perfil das seções menos escolarizadas com o das mais escolarizadas
-- Primeiro, na CTE, o NTILE(4) divide as seções em 4 grupos do mesmo tamanho, do menor para o maior perc_superior
-- Deixei de fora as seções com menos de 50 eleitores, pelo motivo da consulta 10
-- Depois comparo os grupos usando a mesma média ponderada da consulta 13
-- Aqui o COUNT(*) está certo, porque eu quero contar seções, e cada linha da view é uma seção
WITH secoes AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY perc_superior) AS quartil
    FROM perfil_por_secao
    WHERE total_eleitores >= 50
)
SELECT quartil,
       COUNT(*) AS secoes,
       ROUND(SUM(perc_70_mais * total_eleitores) / SUM(total_eleitores), 1) AS perc_70_mais,
       ROUND(SUM(perc_analfabeto * total_eleitores) / SUM(total_eleitores), 1) AS perc_analfabeto
FROM secoes
GROUP BY quartil;
-- Idosos: as seções mais escolarizadas (quartil 4) têm 2,4 vezes mais eleitores com 70+ do que as menos escolarizadas (13,2% contra 5,4%)
-- Analfabetos: é o contrário, as seções menos escolarizadas têm 14 vezes mais (1,4% contra 0,1%)
-- Os dois grupos de voto facultativo estão em lugares opostos do DF,
-- então uma campanha para incentivar o voto precisaria de estratégias diferentes para cada um


-- 15. JUNTANDO O PERFIL DE CADA SEÇÃO COM O BAIRRO, A LOCALIZAÇÃO E A ACESSIBILIDADE
-- O arquivo do perfil só tem o número da zona e da seção, então no mapa ia aparecer "zona 1, zona 2..." e ninguém saberia que lugar é esse
-- Por isso eu baixei um segundo arquivo do TSE, o de locais de votação (eleitorado_local_votacao_2026, gerado em 05/10/2026),
-- e guardei só o DF na tabela locais_votacao. Para cada seção ele traz:
--   nm_bairro: o bairro da escola, para dar nome às regiões
--   latitude e longitude: para colocar cada escola como um ponto no mapa do Tableau
--   ds_acessibilidade: se a seção tem acessibilidade ou não, para responder se os eleitores com deficiência conseguem votar com estrutura adequada
-- Eu ligo as duas tabelas por zona E seção juntas, porque o número da seção se repete em zonas diferentes (consulta 1)
-- Uso LEFT JOIN para manter todas as seções do perfil, mesmo se alguma não tivesse local
-- A locais_votacao tem 7.050 seções, 8 a mais que o perfil: são seções novas, criadas depois de julho, quando o perfil foi gerado
-- Elas ficam de fora porque não tenho o perfil dos eleitores delas
SELECT perfil.*,
       local.nm_bairro,
       local.latitude,
       local.longitude,
       local.ds_acessibilidade
FROM perfil_por_secao AS perfil
LEFT JOIN locais_votacao AS local
    ON perfil.nr_zona = local.nr_zona
   AND perfil.nr_secao = local.nr_secao;

-- 16. VIEW FINAL PARA O TABLEAU: PERFIL + BAIRRO + LOCALIZAÇÃO + ACESSIBILIDADE DE CADA SEÇÃO
-- Aqui eu salvei a consulta 15 como uma view, para ter uma tabela final pronta para exportar
-- Ela junta tudo o que eu preciso no Tableau numa linha por seção:
-- o perfil dos eleitores (perfil_por_secao) + bairro, localização no mapa e acessibilidade (locais_votacao)
-- Eu NÃO tirei aqui as seções com menos de 50 eleitores (consulta 10)
-- Preferi deixar todas e criar um filtro no Tableau, assim quem olhar o dashboard vê como eu tratei esse problema
CREATE VIEW secoes_para_tableau AS
SELECT perfil.*,
       local.nm_bairro,
       local.latitude,
       local.longitude,
       local.ds_acessibilidade
FROM perfil_por_secao AS perfil
LEFT JOIN locais_votacao AS local
    ON perfil.nr_zona = local.nr_zona
   AND perfil.nr_secao = local.nr_secao;

-- Conferindo se a view tem uma linha por seção
SELECT COUNT(*) FROM secoes_para_tableau; -- 7.042 linhas, igual ao número de seções do perfil, então o JOIN não duplicou nem perdeu nenhuma seção


-- 17. CORRIGINDO OS NOMES DOS BAIRROS DO GAMA E DE BRAZLÂNDIA
-- Quando fiz o gráfico de bairros no Tableau, o Gama não aparecia
-- Olhando os nomes das escolas, descobri o motivo: no arquivo do TSE os bairros do Gama se chamam só
-- 'SETOR LESTE', 'SETOR SUL', 'SETOR CENTRAL'... e Brazlândia também tem um 'SETOR NORTE' e um 'SETOR SUL'
-- Então o 'SETOR SUL' do gráfico misturava duas cidades diferentes, e quem olhasse não saberia de onde era
-- Pensei em tirar esses bairros do gráfico, mas isso ia apagar o Gama inteiro
-- Em vez disso, criei a coluna bairro com o nome da cidade entre parênteses, e.g. 'SETOR LESTE (GAMA)'
-- Uso a zona para saber a cidade (zona 17 = Gama, zona 16 = Brazlândia) e o LIKE 'SETOR %' para pegar só os bairros que começam com SETOR
-- A zona entra na condição porque o Setor Sudoeste (zona 11) também começa com SETOR, mas é um bairro de Brasília e não pode ganhar '(GAMA)'
-- Mantive a coluna nm_bairro original do TSE, para não perder o dado como veio
-- Uma view não muda depois de criada, então primeiro apago e depois crio de novo
DROP VIEW secoes_para_tableau;

CREATE VIEW secoes_para_tableau AS
SELECT perfil.*,
       local.nm_bairro,
       CASE
           WHEN perfil.nr_zona = 17 AND local.nm_bairro LIKE 'SETOR %' THEN local.nm_bairro || ' (GAMA)'
           WHEN perfil.nr_zona = 16 AND local.nm_bairro LIKE 'SETOR %' THEN local.nm_bairro || ' (BRAZLÂNDIA)'
           ELSE local.nm_bairro
       END AS bairro,
       local.latitude,
       local.longitude,
       local.ds_acessibilidade
FROM perfil_por_secao AS perfil
LEFT JOIN locais_votacao AS local
    ON perfil.nr_zona = local.nr_zona
   AND perfil.nr_secao = local.nr_secao;

-- Conferindo os nomes novos
SELECT bairro, SUM(total_eleitores) AS eleitores
FROM secoes_para_tableau
GROUP BY bairro
ORDER BY bairro; -- 70 bairros, e.g. 'SETOR LESTE (GAMA)' e 'SETOR SUL (BRAZLÂNDIA)'. O Setor Sudoeste continua sem cidade, como devia
-- Também percebi que o menor bairro (Taquari) tem 499 eleitores, então nenhum bairro tem o problema das seções minúsculas
-- Por isso não usei filtro de tamanho no gráfico de bairros
