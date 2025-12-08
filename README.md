📘 README – Fluxo de Trabalho com GitHub em Duas Máquinas (Casa e Trabalho)

Este guia explica como configurar, sincronizar e trabalhar com um projeto Flutter usando Git + GitHub em dois computadores diferentes.
Com isso você pode continuar o desenvolvimento tanto em casa quanto no trabalho, mantendo tudo sincronizado.

🚀 1. Criando o Repositório no GitHub

Acesse: https://github.com

Clique em New Repository

Informe o nome (ex.: app_financeiro_casal)

Deixe como Public ou Private

Não marque README, .gitignore ou LICENSE

Clique em Create Repository

Guarde a URL do repositório, por exemplo:

https://github.com/JeffVane/app_financeiro_casal.git

🧰 2. Enviando o Projeto Pela Primeira Vez (Máquina A)

Abra o projeto no VS Code e execute no terminal:

Inicializar o Git
git init
git add .
git commit -m "Primeiro commit do app financeiro"

Conectar ao GitHub
git remote add origin https://github.com/SEU_USUARIO/app_financeiro_casal.git

Enviar para o GitHub
git branch -M main
git push -u origin main


Se o Git pedir senha, você deve usar um token de acesso pessoal (PAT).
(Se ainda não criou, pode gerar em Settings → Developer Settings → Personal Access Tokens → Generate Token.)

🏠 3. Trabalhando em Outra Máquina (Máquina B – Casa ou Trabalho)

Para começar a trabalhar no segundo computador, você deve clonar o repositório:

git clone https://github.com/SEU_USUARIO/app_financeiro_casal.git


Depois entre na pasta:

cd app_financeiro_casal


Agora essa máquina está pronta para desenvolver.

🔄 4. Fluxo Diário de Trabalho
⬇️ Sempre antes de começar a trabalhar:

Baixe as atualizações do GitHub:

git pull


Isso garante que você está trabalhando com a versão mais atualizada.

✍️ 5. Como Fazer Alterações e Enviar para o GitHub

Sempre que fizer modificações:

Adicionar arquivos alterados
git add .

Criar um commit
git commit -m "Descrição das alterações"

Enviar para o GitHub
git push

🔁 6. Trabalhando em Duas Máquinas (Casa ↔ Trabalho)
📤 Se você alterou algo na máquina A e quer enviar para máquina B:

Na máquina A:

git add .
git commit -m "Alterações feitas na máquina A"
git push


Na máquina B:

git pull

📤 Se você alterou algo na máquina B e quer enviar para máquina A:

Na máquina B:

git add .
git commit -m "Alterações feitas na máquina B"
git push


Na máquina A:

git pull

⚠️ 7. Regras Importantes para Evitar Problemas

Sempre faça git pull antes de começar a trabalhar.

Sempre faça git push quando terminar de trabalhar.

Nunca trabalhe em duas máquinas simultaneamente sem antes sincronizar.

Para projetos Flutter, use um .gitignore adequado (excluir build/, .dart_tool/, etc.).


🎉 Pronto!

Agora você tem um fluxo profissional de trabalho usando GitHub em múltiplos computadores, com segurança e sincronização total.
