# HOLLER — não responda

Terror e sobrevivência em primeira pessoa para PC, feito em Godot 4.7.

Outubro de 1987. O voo 609 cai de madrugada no meio dos montes Apalaches. As poltronas
estão vazias, os cintos continuam afivelados e alguma coisa na mata já sabe o seu nome.
A lua mal entra na mata e a lanterna não dura para sempre. Ache a civilização.

<p align="center">
  <a href="https://github.com/AvoSalesCompany/apalache/releases/latest/download/HOLLER-Instalador.exe">
    <img src="docs/baixar.svg" alt="Baixar o jogo HOLLER para Windows" width="460">
  </a>
</p>
<p align="center">
  Baixe, abra o instalador e clique no ícone <b>HOLLER</b> na área de trabalho. Windows 10 ou 11 (64 bits).
</p>

![Menu](docs/menu.jpg)

| | |
|---|---|
| ![Cabine do voo 609](docs/cabine.jpg) | ![Destroços](docs/destrocos.jpg) |
| ![Um dos dezoito](docs/vigia.jpg) | ![Riacho](docs/riacho.jpg) |

## Como jogar

**Jogar pronto:**
1. Clique no botão **Baixar o jogo** aqui em cima.
2. Abra o `HOLLER-Instalador.exe`. Se o Windows avisar que o aplicativo é desconhecido, clique em
   **Mais informações** e depois em **Executar assim mesmo** (o jogo ainda não tem assinatura digital).
3. Clique em **Instalar**. O ícone do HOLLER aparece na área de trabalho: é só clicar e jogar.

Precisa de placa de vídeo com Vulkan. Ficou lento? *Esc → Opções → Qualidade: Baixa*.

**Pelo código:**
1. Baixe o [Godot 4.7.2](https://godotengine.org/download) (versão padrão, 64 bits).
2. Abra o Godot, clique em *Importar* e escolha `jogo/project.godot`.
3. Aperte **F5**.

| Tecla | Ação |
|---|---|
| WASD / mouse | andar / olhar |
| Shift / Ctrl / Espaço | correr / agachar / pular e proteger a cabeça no avião |
| E | usar, pegar e soltar objetos (algumas coisas pedem segurar) |
| F | lanterna |
| Q | gritar por socorro (pense bem) |
| C | segurar a bússola |
| Clique esquerdo | arremessar pedra ou objeto para distrair |
| Botão direito | focar a visão |
| H / Tab / Esc | curativo / caderno / pausa |

Jogue com fones de ouvido: **os grilos são o seu radar.** Se o mato calar, ele está perto.

## O que já existe (v0.2)

- **Abertura:** turboélice regional dos anos 80 com janelas ovais, voo noturno, pane, turbulência e queda.
- **Lanterna** com pilhas que acabam e que falha quando algo está perto. A luz também mostra você.
- **Os dezoito:** passageiros parados na mata, de longe, olhando. Olhos que devolvem a luz, vultos, sustos.
- **Começo seguro:** até sair da cabana a criatura só observa, e ler nunca é interrompido.
- **Física:** tudo que é sólido tem colisão; malas, caixas, cadeiras e latas podem ser empurradas, pegas e jogadas.
- **Mapa aberto** de 1 km²: 32 mil árvores, riacho, cabana, cemitério, torre de incêndio, ponte, rodovia e posto.
- **O Chamador:** criatura com visão, audição e memória, que imita a voz de quem morreu.
- **Diretor de tensão:** um segundo cérebro decide quando apertar e quando dar descanso.
- **Sobrevivência:** frio, fôlego, ferimentos, medo e exposição ao luar (ícone da lua).
- **As regras da serra** são mecânicas: não grite, não responda, não siga as luzes, cale quando o mato calar.
- **Dois finais**, salvamento automático, opções de qualidade e legendas em português.

## Organização

```
jogo/            projeto Godot
  cenas/         cena inicial
  scripts/       código (GDScript, comentado em português)
  shaders/       lua, céu, névoa, água, terreno, pele da criatura
  mod/ tex/      modelos e texturas
  som/           áudio sintetizado
  dados/         mundo pré-calculado
  ferr/          ferramenta que recalcula o mundo
ferramentas/     scripts que baixam assets e geram áudio, folhagem e ícone
instalador/      instalador do Windows (Inno Setup)
.github/         monta e publica o jogo quando uma versão é marcada
docs/            design, pesquisa e imagens
```

| Quero mudar... | Arquivo |
|---|---|
| Roteiro, notas, finais | `jogo/scripts/historia.gd` |
| Ritmo do terror, vozes, luzes falsas | `jogo/scripts/diretor.gd` |
| Comportamento da criatura | `jogo/scripts/criatura.gd` |
| Vigias, vultos e sustos | `jogo/scripts/anomalias.gd` e `vigia.gd` |
| Lanterna | `jogo/scripts/lanterna.gd` |
| Modelo do avião | `jogo/scripts/aeronave.gd` |
| Objetos com física | `jogo/scripts/objeto_fisico.gd` |
| Andar, frio, fôlego | `jogo/scripts/jogador.gd` |
| Luz da lua e neblina | `jogo/scripts/floresta.gd`, função `_luz_e_ceu` |
| Posição dos lugares, rio e estradas | `jogo/scripts/mundo.gd`, depois rodar a ferramenta abaixo |
| Cena do avião | `jogo/scripts/aviao.gd` |

### Ferramentas

Recalcular o mundo depois de mexer em `mundo.gd` ou `assar.gd`:

```bash
godot --path jogo --headless res://ferr/assar.tscn -- mundo
```

Robô que joga a partida inteira e relata onde travou:

```bash
godot --path jogo -- robo=1 vel=3
```

Publicar uma versão nova (o GitHub monta o instalador e atualiza o botão de download sozinho):

```bash
git tag v0.3.0
git push origin v0.3.0
```

Exportar o `.exe` no seu PC: no Godot, *Editor → Gerenciar modelos de exportação*, depois *Projeto → Exportar → Windows*.

## Créditos e licenças

Veja [CREDITOS.md](CREDITOS.md). Importante para a Steam: **as falas são provisórias**
(voz sintética do Windows) e precisam ser regravadas antes de vender o jogo.
