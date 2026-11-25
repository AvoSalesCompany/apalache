# Design e pesquisa

## Pesquisa: os Apalaches

| Lenda ou crença | O que dizem | Como virou jogo |
|---|---|---|
| Não responda se chamarem seu nome | A voz quer atrair você ([East Tennessean](https://easttennessean.com/2024/11/06/cryptids-of-the-south-monster-hunter-safety/)) | Vozes chamam "Alex" fora do caminho. Gritar com Q denuncia você |
| Não assobie à noite | Assobiar chama atenção do que está na mata ([Daily Signal](https://www.dailysignal.com/2025/10/29/american-folklore-is-more-than-just-scary-stories-it-carries-a-value-system/)) | O assobio é o primeiro sinal da criatura |
| "Not Deer" | Um cervo com algo errado, olhos para a frente ([HowStuffWorks](https://science.howstuffworks.com/science-vs-myth/strange-creatures/not-deer.htm)) | A forma da criatura de longe |
| Luzes de Brown Mountain | Luzes sem explicação na serra da Carolina do Norte ([The Collector](https://www.thecollector.com/appalachian-folk-stories-scary/)) | A luz que segue o avião e as luzes falsas na mata |
| Raven Mocker (Cherokee) | Ronda quem está para morrer ([Sacred Texts](https://sacred-texts.com/book/myths-of-the-cherokee/read/120-the-raven-mocker)) | Só inspirou o clima. É tradição sagrada, então não foi usada como monstro |
| Rododendro fechado ("inferno de louro") | Moitas quase impenetráveis | Esconderijos |

Observação honesta: parte disso é folclore recente da internet. O *Skeptoid* diz que o "Not Deer" não é tradição
antiga, e a frase "não, você não ouviu" veio de vídeos. O jogo não afirma que as lendas são antigas.

## Pesquisa: terror atual na Steam

- **Dois cérebros** ([Game Developer](https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation)):
  um diretor sabe onde você está e mede a pressão. A criatura só conhece o que vê e ouve. Aqui: `diretor.gd` e `criatura.gd`.
- **Quase sem armas, visão limitada**: só no cerco final existe um rifle, lento e com pouca munição.
- **Som como ferramenta e risco**: correr, pisar em galho ou gritar atrai. Pedras distraem.
- **Recursos curtos**: curativos, pedras, calor, fôlego.
- **Interface mínima**: barras só aparecem quando importam.
- **Construir antes de assustar**: o susto precisa de preparação e de descanso depois
  ([Game Developer](https://www.gamedeveloper.com/design/the-time-and-place-for-jump-scares-according-to-horror-devs),
  [Game Wisdom](https://game-wisdom.com/critical/jumpscare-horror-game-design)). Em `anomalias.gd` há intervalo mínimo entre sustos fortes e nunca se repete o mesmo em seguida.
- **Esconder é melhor que mostrar**: neblina e quarto escuro com lanterna ([Epic](https://store.epicgames.com/news/why-horror-games-are-so-scary)).
- **O que streamers jogam**: terror que rende reação e história compartilhável
  ([Streams Charts](https://streamscharts.com/news/twitch-horror-games-halloween-2025), [Gamesight](https://blog.gamesight.io/horror-gaming-creator-ecosystem/)).

## Os dezoito

Dezenove a bordo, falta um: você. Os outros estão na mata, parados, altos demais, boca aberta demais.
Não atacam. Somem quando encarados. A voz que chama sai deles.

## Roteiro (v0.3)

0. **Voo 609** — conversa com a vizinha, revista, comissária com o lanche. Só depois a luz na asa, a pane e a queda.
1. **Destroços, amanhecer** — acordar entre os mortos. Mochila com mapa, casaco, curativos, bússola, lanterna.
2. **Trilha, de dia** — nenhum monstro. Bandos de pássaros fogem, altos, para o sul.
3. **Cold Holler, tarde** — Caleb, Elias (a história dos montes), Hannah, Amos e Ruth, que dá abrigo. O sol se põe.
4. **Duas e quarenta e sete** — os cachorros calam, passos no telhado, o ataque.
5. **Fuga** — a trilha do cemitério até a Torre 4, com vultos e a criatura por perto, sem poder matar.
6. **Torre 4** — a chave está na privada; o gerador, seco; a gasolina ficou na vila destruída.
7. **Cerco** — depois do rádio ela pode matar: aparece, golpeia, some. Três golpes. Três tiros a matam.
8. **Amanhecer** — a polícia sobe a estrada de serviço. "Não tem vila nenhuma nesta serra desde 1931."

Finais: **Silêncio** (matou a criatura) e **Amanhecer** (aguentou até o sol nascer).
## Ideias para as próximas versões

- Vozes humanas gravadas; nome do jogador escolhido no começo.
- Braços visíveis em primeira pessoa; animação de pegar e abrir.
- Mina abandonada como caminho alternativo e terceiro final.
- Sobrevivente escondido em quem se deve ou não confiar.
- Noite que avança (a lua se move), chuva e neblina densa.
- Controle de videogame, inglês, conquistas da Steam.
