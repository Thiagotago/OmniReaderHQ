# Decisões de arquitetura

- O motor de catálogo e leitura depende de contratos (`CatalogSource` e `ComicArchiveProvider`), sem endereço de origem embutido.
- `BloggerSource` implementa a extração genérica de metadados de blogs com estrutura padrão Blogger.
- A URL é informada pelo usuário na primeira execução e persistida localmente.
- O serviço remoto escolhe a estratégia de obtenção de arquivos pelo host do link de cada capítulo; os dados baixados são extraídos e preparados em cache local.
- O suporte a fontes e formatos deve ser validado com conteúdo que o usuário esteja autorizado a acessar.
