// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




/// TITLE PAGE template partial
#import "@preview/icu-datetime:0.1.2": fmt-datetime, fmt-date

///// STYLE ELEMENTS FOR TYPST TEMPLATES


  // Colour definition

  #let grey0 =  rgb("#030303")
  #let grey1 =  rgb("#6B6B6B")
  #let grey2 =  rgb("#A6A6A6")
  #let grey3 =  rgb("#D6D6D6")
  #let scpored = rgb("#e6142d")
  #let scpodarkred = rgb("#770C19")
  #let colourtype = rgb("#EEC900")
  #let ife1 = rgb("#7D0000")
  #let ife2 = rgb("#21606E")
  #let ifegrey = rgb("#DDDBDB")

  // Font definition
  #let main_title_font = "Arimo"
  #let serif_font = "Merriweather"

 // Callout settings
  
#let callout(
body: [],
title: "Callout",
background_color: none,
icon: none,
icon_color: none,
body_background_color: white) = {
  let _bg = rgb("#faf0f3")
  let _ic = rgb("#faf0f3")
  let _bbg =  rgb("#faf0f3")
  block(
    breakable: true,
    fill: _bg,
    stroke: (paint: _ic, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      breakable: true,
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        breakable: true,
        fill: _bg,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(_ic, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          breakable: true,
          inset: 1pt,
          width: 100%,
          block(breakable: true, fill: _bbg, width: 100%, inset: 8pt, align(left, body)))
      }
    )
}


#let title-page(
  title:[],
  subtitle:[],
  authors: none, email:[],
  first_publish: none,
  abstract: none, year: none,
  number:[],
  draft: false,
  language: "fr",
  body) = {

  let marge = 3.5cm
  let ph = 29.7cm // page height for a4
  let pw = 21.0cm // page width for a4
  let logo_column = 4cm
  let lc_space = 0.75cm
  let line_x = -0.5cm + (logo_column - marge) + lc_space*2

  let grey0 =  rgb("#030303")
  let grey1 =  rgb("#6B6B6B")
  let grey2 =  rgb("#A6A6A6")
  let grey3 =  rgb("#D6D6D6")
  let scpored = rgb("#e6142d")
  let scpodarkred = rgb("#770C19")
  let colourtype = rgb("#EEC900")
  let ife1 = rgb("#7D0000")
  let ife2 = rgb("#21606E")
  let ifegrey = rgb("#DDDBDB")

  // Font definition
  let main_title_font = "Arimo"
  let serif_font = "Merriweather"

// Author block

let nrows = calc.min(authors.len(), 3)

let authorblock()={
if authors != none {
    grid(
      rows: nrows,
      row-gutter: 0.5em,
      ..authors.map(author =>
          align(left)[
            #text(author.name, weight: "bold",size: 11pt), #text(author.affiliation,style:"italic",size: 11pt)
          ]
      )
    )

  }

}




  // Date formatting



  let main_date = if first_publish != none {
  first_publish.text
  } else {
  none }


 let pretty_date =   if main_date != none {

    let date_decomp = main_date.split("-")
    let year_fp = int(date_decomp.at(0))
    let month_fp = int(date_decomp.at(1))
    let day_fp = int(date_decomp.at(2))
    let date_formatted = datetime(year: year_fp, month: month_fp, day: day_fp)

    fmt-date(date_formatted, length: "long", locale: language)

  }

  // Année affichée : on privilégie `annee` (yaml) ; à défaut on extrait
  // l'année de la date de première publication.
  let display_year = if year != none {
    year
  } else if main_date != none {
    main_date.split("-").at(0)
  } else {
    none
  }

    // Page formatting

  set page(margin: (top: marge, rest: marge))

  set text(font: main_title_font, size: 14pt)
  set heading(numbering: "1.1.1")

  // place(top + right, text(blue,"+")) // position tester

  /////// 1. logo position and line

  place(top + left, dx: -marge+lc_space,dy:-2cm,
        image("/_extensions/ofce/ofce/img/ofce_m.png", width: logo_column*0.7)
        )

  place(bottom + left, dx: -marge+lc_space,dy: 2cm,
        image("/_extensions/ofce/ofce/img/sciencespo.png", width: logo_column*0.7)
      )
  place(left,
        line(start: (line_x, 0cm), end: (line_x,  ph - 2*marge),
  stroke: (thickness: 1.25pt, paint: grey1)))

  //// 2. Title Position



  place(dx: 2cm,dy: 4cm,
    box(width: 13cm,
      align(horizon + left)[
        #text(size: 24pt, title, fill: ife2, weight: "bold", font: serif_font)
        #v(1em)
        #text(subtitle,fill: grey1)
        #v(2em)

        #authorblock()

        // #text(date_decomp, size: 14pt)


      ]/// end align
    ) /// end box,
  )





  //// 3. Publishing date And Issue number

  if not draft {
  place(top+right ,dy:-2cm,dx: marge ,
        square(fill: ife1, size: 2cm,align(center+horizon,text(fill: white,size: 1.5cm,number)))
      )

  if display_year != none {
  place(top+right ,dy:0cm,dx: marge ,
        text(fill: ife1, size: 0.9cm,text(display_year))
      )
  }
  } else {
  place(top+right ,dy:-2cm,dx: marge ,
        box(fill: ife1, inset: 8pt, radius: 2pt,
          align(center+horizon,text(fill: white,size: 0.9cm, weight: "bold","BROUILLON")))
      )
  }

  place(top + right, dx:+1.25cm,dy:-1.5cm, align(horizon,text(fill: gray ,size:1cm,weight: "bold", font: serif_font,style:"italic","Document de travail")))


  place(bottom + right, dx: 1.5cm,

  [
    #text({
      if(first_publish != none){
        [Première publication : ]
        }
        }, weight: "semibold", size: 10pt

        )
    #text({
      if(first_publish != none){
        [ #pretty_date \ ]
        }
        }, size: 10pt

        )


  ]

  )
  //// 4. Abstract

  place(bottom, dx: 2*lc_space + line_x, dy: -1*line_x,
  clearance: 4cm,
    box(fill: grey3, baseline: 100%,width: 13cm,inset: 1em,
      text(style: "italic",abstract,size: 10pt)
      )
    )

  //// 5. Internal cover page
  pagebreak()
  set page(fill: none, margin: auto)





  /// start
  //pagebreak()
  body
}


#import "@preview/icu-datetime:0.1.2": fmt-datetime, fmt-date


///// STYLE ELEMENTS FOR TYPST TEMPLATES

  // Colour definition

  // #let grey0 =  rgb("#030303")
  // #let grey1 =  rgb("#6B6B6B")
  // #let grey2 =  rgb("#A6A6A6")
  // #let grey3 =  rgb("#D6D6D6")
  // #let scpored = rgb("#e6142d")
  // #let scpodarkred = rgb("#770C19")
  // #let colourtype = rgb("#EEC900")

  // // Font definition
  // #let main_title_font = "Open sans"
  // #let serif_font = "Open sans"


/// CORE TEXT


#let preprint(
  title: none,
  subtitle: none,
  running-head: none,
  authors: none,
  affiliations: none,
  abstract: none,
  keywords: none,
  authornote: none,
  citation: none,
  first_publish: none,
  leading: 0.6em,
  spacing: 1em,
  first-line-indent: 0cm,
  linkcolor: rgb(0, 0, 0),
  paper: "a4",
  language:"fr",
  region: "US",
  font: ("Times", "Times New Roman", "Arial"),
  fontsize: 11pt,
  section-numbering: none,
  toc: false,
  toc_title: "contents",
  toc_depth: none,
  toc_indent: 1.5em,
  number: none,
  draft: false,
  bibliography-title: "Références",
  bibliography-style: "apa",
  cols: 1,
  col-gutter: 4.2%,
  doc,
) = {

  /* Document settings */

  let grey0 =  rgb("#030303")
  let grey1 =  rgb("#6B6B6B")
  let grey2 =  rgb("#A6A6A6")
  let grey3 =  rgb("#D6D6D6")
  let scpored = rgb("#e6142d")
  let scpodarkred = rgb("#770C19")
  let colourtype = rgb("#EEC900")

  // Font definition
  let main_title_font = "Arimo"
  let serif_font = "Merriweather"


  // Date formatting

    let main_date = if first_publish != none {
  first_publish.text
  } else {
  none }


 let pretty_date =   if main_date != none {

    let date_decomp = main_date.split("-")
    let year_fp = int(date_decomp.at(0))
    let month_fp = int(date_decomp.at(1))
    let day_fp = int(date_decomp.at(2))
    let date_formatted = datetime(year: year_fp, month: month_fp, day: day_fp)

    fmt-date(date_formatted, length: "long", locale: language)

  }



  // Set link and cite colors
  show link: set text(fill: linkcolor)
  show cite: set text(fill: linkcolor)

 show figure.where(kind: "quarto-float-apptbl"): set block(breakable: true)
 show figure.where(kind: table): set block(breakable: true)

  // Allow custom title for bibliography section
  set bibliography(title: bibliography-title, style: bibliography-style, )

  // Format author strings here, so can use in author note
  let author_strings = ()
  if authors != none {
    for a in authors{
      let author_string = [#a.name]
      author_strings.push(author_string)
    }

  }

  // Page settings (including headers & footers)
  set page(
    paper: paper,
    margin: (inside: 3.5cm, outside: 2.5cm, rest: 3cm),
    numbering: "1",
    header-ascent: 50%,
    header:

        // Page 3
              context if here().page() == 3 {

          grid(
          columns: (1fr, 1fr),
          align(left+ bottom)[#text(if draft [Document de travail OFCE — brouillon] else [Document de travail OFCE nº #number\ publié le #pretty_date], style: "italic")],
          align(right + bottom)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ]

          )


        } else {

          if(calc.even(here().page())){

            grid(
            columns: (1fr, 1fr),
            align(left + bottom)[#counter(page).display()],
            align(right + bottom)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ]

          )

          } else {
          grid(
            columns: (1fr, 1fr),
            align(left)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ],
            align(right)[#counter(page).display()]
          )


          }

          // Page >1 header has running head and page number

        line(start: (0cm, -0.5em), end: (15cm,  -0.5em),
  stroke: (thickness: 0.25pt, paint: grey1))
        }
    ,
    footer-descent: 24pt,
    footer:

              context if here().page() == 3 {

        } else {

        }

  )

  // Paragraph settings
  set par(
    justify: true,
    leading: leading,
    first-line-indent: first-line-indent,
    spacing: spacing
  )


  // Text settings
  set text(
    region: region,
    font: font,
    size: fontsize
  )

  // Headers
  set heading(
    numbering: section-numbering
  )
  // Level 1 headers
  show heading.where(
    level: 1
  ): it => block(width: 100%, below: 1em, above: 1.25em)[
    #set text(size: fontsize*1.3, weight: "bold", font: serif_font)
    #it
  ]
  // Level 2 headers
  show heading.where(
    level: 2
  ): it => block(width: 100%, below: 1em, above: 1.25em)[
    #set text(size: fontsize*1.05)
    #it
  ]
  // Level 3 headers
  show heading.where(
    level: 3
  ): it => block(width: 100%, below: 0.8em, above: 1.2em)[
    #set text(size: fontsize, style: "italic")
    #it
  ]
  // Level 4 headers are in paragraph
  show heading.where(
    level: 4
  ): it => box(
    inset: (top: 0em, bottom: 0em, left: 0em, right: 1em),
    text(size: 1em, weight: "bold", it)
  )
  // Level 5 headers are in paragraph
  show heading.where(
    level: 5
  ): it => box(
    inset: (top: 0em, bottom: 0em, left: 0em, right: 1em),
    text(size: 1em, weight: "bold", style: "italic", it)
  )


pagebreak()


  /* Content */



v(4cm)



text(title, size: 24pt, weight: "bold", font: serif_font)

if subtitle != none {
v(1em)
text(subtitle, size: 16pt, weight: "semibold")
}


v(1em)

text(author_strings.join(", ", last: " & "))

  // Separate content a bit from front matter
  v(4em)

  // Show document content with cols if specified
  if cols == 1 {
    doc
  } else {
    columns(
      cols,
      gutter: col-gutter,
      doc
    )
  }

v(4cm)


// text("Fin" , size: 14pt, weight: "bold")
}

// Remove gridlines from tables
#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)


#show: body => title-page(
  title: [La reprise d'emploi est-elle toujours rémunératrice?],
  email: "mailto: student@youraddress.com",
  subtitle: [Contradictions des politiques de lutte contre la pauvreté et pistes pour les surmonter],  authors: (
          (
        name: [Guillaume Allègre],
        affiliation: [OFCE, Sciences Po Paris],
        email: [guillaume.allegre\@sciencespo.fr] ),
      
          (
        name: [Muriel Pucci],
        affiliation: [OFCE & Université Paris 1],
        email: [muriel.pucci\@gmail.com] ),
      
      ),
  abstract: [],
  year: [2025],
  number:[24],
  draft: false,

  first_publish: [2025-11-21],

  language: "fr",
  body
)

#show: doc => preprint(
  title: [La reprise d'emploi est-elle toujours rémunératrice?],
  subtitle: [Contradictions des politiques de lutte contre la pauvreté et pistes pour les surmonter],
  number:[24],
  draft: false,
  authors: (
          (
        name: [Guillaume Allègre],
        affiliation: [OFCE, Sciences Po Paris],
        email: [guillaume.allegre\@sciencespo.fr] ),
      
          (
        name: [Muriel Pucci],
        affiliation: [OFCE & Université Paris 1],
        email: [muriel.pucci\@gmail.com] ),
      
      ),
  first_publish: [2025-11-21],
  citation: (
    type: "article-journal",
    container-title: "Document de travail de l'OFCE",
    doi: "",
    url: "https:\/\/https:\/\/github.com/gallegre/GainEmploi"
  ),
  language: "fr",
  abstract: [Depuis les réformes instaurant le RSA activité (2008) puis la prime d'activité (2016), l'emploi est toujours plus rémunérateur que l'inactivité. Toutefois, travailler ne garantit pas la sortie de la pauvreté. Cela s'explique notamment par le fait que le revenu minimum versé aux personnes d'âge actif est très faible et maintient la plupart du temps les personnes sans emploi sous le seuil de grande pauvreté : le travail paie plus que l'assistance, mais les travailleurs partent de trop bas. Des pistes de réforme sont proposées permettant de concilier les trois objectifs des pouvoirs publics: faire en sorte que le travail soit toujours rémunérateur ; faire en sorte que le travail protège de la pauvreté ; soutenir le revenu des ménages les plus modestes.],
  keywords: [Assistance, prime d'activité, smic, gains à l'emploi, trappes à inactivité],
  paper: "a4",
  font: ("Arimo",),
  section-numbering: "1.1.a",
  doc,
)

= Introduction : les objectifs de la lutte contre la pauvreté par l'emploi
<introduction-les-objectifs-de-la-lutte-contre-la-pauvreté-par-lemploi>
Y a-t-il de bonnes raisons de reprendre un emploi rémunéré au salaire minimum quand on reçoit des prestations sociales ? S'il existe des avantages non monétaires à la reprise d'emploi, notamment en termes d'insertion sociale, la question posée de façon récurrente est celle des gains monétaires à l'emploi.

On peut ainsi distinguer deux questions : l'existence des gains monétaires à la reprise d'emploi et la sensibilité des travailleurs à ces gains (soit l'élasticité de l'offre de travail). Nous nous intéressons ici uniquement à la première de ces questions : le travail au Smic paye-t-il plus que l'assistance ?#footnote[Sicsic (2023) propose une revue de littérature sur l'élasticité de l'offre de travail.]

La stratégie nationale de prévention et de lutte contre la pauvreté (SNPLP), publiée en 2018 permet de préciser les objectifs de la politique sociale en termes de lutte contre la pauvreté et de gains à l'emploi. Elle prévoit la création d'un revenu universel d'activité (RUA) permettant à chacun de vivre décemment et d'accéder plus rapidement à l'emploi. Plus précisément, on peut dégager les trois objectifs suivant de la SNPLP :

+ « faire en sorte que le travail paye et qu'il paye de la même façon dans tous les cas » ;
+ « engager une politique déterminée de sortie de la pauvreté par le travail »
+ « garantir un soutien financier aux ménages modestes »

Puisque le travail doit faire sortir de la pauvreté, la stratégie admet implicitement que les personnes sans emploi puissent être pauvres. Mais il ne faut pas que leurs privations soient trop sévères, en particulier lorsqu'elles ont des enfants. En revanche, la pauvreté en emploi est perçue comme une anomalie que les politiques publiques doivent corriger (voir Allegre (2024)).

Ce document évalue le système socio-fiscal actuel à l'aune de ces trois objectifs puis discute de ses contradictions avant d'explorer des pistes de réforme.

Pour répondre à la question « la reprise d'emploi est-elle rémunératrice?” de façon concrète, nous raisonnons à partir de cas-types, sur la base de la législation en vigueur en avril 2024. Le principe est de comparer les revenus disponibles de ménages similaires mais dans lesquels seul le revenu du travail diffère. Cela permet d'illustrer les gains à la reprise d'emploi d'un travailleur selon le salaire obtenu et la configuration familiale de son ménage. Les cas-types représentent des situations pérennes~; ils ne prennent en compte ni les coûts d'organisation liés à la reprise d'emploi, ni les gains liés à la possibilité de cumul intégral temporaires entre revenus professionnels et RSA.~

L'approche par cas-type est simplificatrice. D'une part, les revenus disponibles, ou niveaux de vie, ne tiennent pas compte ni des différences de coûts de la vie induites par le fait de travailler plutôt qu'être au foyer, en particulier dans les ménages avec enfants, ou lorsque le trajet domicile-travail est coûteux ; ni des aides locales sous conditions de ressources (tarification de la cantine scolaire par exemple). D'autre part, elle ne tient pas compte non plus des avantages économiques liés à l'emploi qu'ils soient immédiats (tickets restaurant, prise en charge des cartes de transport) ou différés en termes de droits ouverts de chômage ou de retraite.~L'approche néglige également le fait que les personnes peuvent accorder une valeur différente aux salaires et aux prestations sociales. Néanmoins, cette approche est cohérente avec la définition du niveau de vie utilisée pour mesurer les inégalités de revenus (rapport inter-décile, indice de Gini) et la pauvreté monétaire (voir #ref(<tip-ndvdef>, supplement: [encadré])). Ces indicateurs, largement utilisés dans le débat public, ne tiennent pas compte, eux non plus, de la tarification de la cantine scolaire ou de l'avantage lié aux tickets-restaurant par exemple. Il ne faut donc pas exagérer le caractère simplificateur des cas-types que nous présentons : l'approche par le revenu disponible est une vision simplificatrice mais tangible, qui se traduit concrètement sur le compte en banque. Il y a des avantages à ne pas travailler qui ne se traduisent pas en revenus, mais il y a aussi des avantages à travailler.

#figure([
#block[
#callout(
body: 
[
Le niveau de vie d'un ménage est un indicateur conçu pour comparer les revenus disponibles de ménages de configuration différente en tenant compte des économies d'échelle liées à la vie commune et des dépenses pour les enfants. Il est obtenu en divisant le revenu disponible (revenus professionnels ou de remplacement, revenus fonciers ou financiers auxquels on ajoute les prestations sociales reçues et dont on déduit les impôts directs sur le revenu) de l'ensemble du ménage par un nombre d'unités de consommation. En France et en Europe, les unités de consommation sont définies par l'INSEE et Eurostat selon l'échelle d'équivalence dite de l'OCDE modifiée qui attribue 1 UC au premier adulte du ménage, 0,5 UC aux autres personnes de 14~ans ou plus et 0,3 UC aux enfants de moins de 14~ans (car considérés comme ayant moins de besoins). Selon cette convention, le niveau de vie est considéré comme identique pour une personne seule avec un revenu disponible de 2~000 euros, un couple sans enfant qui dispose 3000 euros (1,5x2000), ou un couple avec un enfants de 10~ans qui dispose de 3~600 euros (1,8x2000).

]
, 
title: 
[Définition du niveau de vie]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
], caption: figure.caption(
position: top, 
[
]), 
kind: "quarto-callout-Astuce", 
supplement: "Tip", 
numbering: callout-numbering, 
)
<tip-ndvdef>


Dans les situations étudiées, les gains à la reprise d'emploi résultent des salaires nets perçus et éventuellement de la prime d'activité. Les «~coûts~» résultent de la baisse des prestations sociales (RSA, allocations logement, prestations familiales…) et, dans certains cas, de l'augmentation de l'impôt sur le revenu.

Le cas-type général commenté dans ce document est celui d'un ménage locataire du parc privé en ville moyenne, éligible, sous condition de ressources, au RSA (l'individu référent est âgé entre 25 et 64~ans) et aux allocations logement, et qui recourt à ces prestations lorsqu'il y a droit. Pour les ménages non éligibles à ces prestations (notamment les propriétaires de leur logement), ou qui n'y recourent pas, les prestations sociales hors-emploi sont bien plus faibles et les gains à la reprise d'emploi sont donc plus importants que ceux calculés ici. Supposant que l'emploi est rémunéré au Smic horaire et que les ménages recourent aux prestations, les gains calculés ici représentent plutôt un minimum qu'un maximum#footnote[Devetter et Valentin (2025) estiment, à partir des déclarations annuelles de données sociales, que moins de 5% des salariés sont réminérés en dessous du smic horaire soit en raison de dérogations au droit commun dans certaines branches (assitantes maternelles ou représentants de commerce par exemple) soit en lien avec un décompte incomplet des heures de travail.]. Pour les ménages avec enfants, nous supposons que les enfants sont d'âge scolaire. Trois situations de reprise d'emploi sont analysées : le mi-temps au Smic (699 euros net mensuels), le temps-plein au Smic (1~399 euros) et le temps plein à 1,5 Smic (2~098 euros).

L'approche par cas-type est critiquable dans la mesure où elle ne représente pas la diversité des situations individuelles. Par construction, elle renseigne, de façon synthétique, sur les caractéristiques du système social et fiscal plutôt que sur celles de l'ensemble des ménages. L'analyse est descriptive et ne présuppose pas que les individus ont le choix entre les différents horaires de travail ou taux de salaire.

= La reprise d'emploi est toujours rémunératrice, mais pas toujours de façon homogène
<la-reprise-demploi-est-toujours-rémunératrice-mais-pas-toujours-de-façon-homogène>
== Des reprises d'emploi rémunératrices
<des-reprises-demploi-rémunératrices>
Dans les cas-types étudiés, le système socio-fiscal actuel garantit que la reprise d'emploi est toujours rémunératrice, mais pas nécessairement toujours dans les mêmes proportions. Pour le mesurer, on utilisera deux indicateurs : le taux de prélèvement effectif et le taux effectif de gain à l'emploi (voir #ref(<tip-teg>, supplement: [encadré])).

#figure([
#block[
#callout(
body: 
[
Outre la variation de revenu disponible du ménage, il est également possible de calculer un taux effectif de prélèvement (TEP) qui correspond à la baisse des transferts sociaux (nets d'impôt) par euro supplémentaire de revenu professionnel. Si, lorsque le revenu d'activité augmente de 1000 euros, les transferts sociaux nets baissent de 400 euros on dira que le TEP est de 40%. Dans ce cas, le revenu disponible augmente de 600 euros.

$ T E P = upright("-Variation des transferts sociaux nets") / upright("Variation du revenu professionnel") = 1 - upright("Variation du revenu disponible") / upright("Variation du revenu professionnel") $

On peut définir le taux effectif de gain à l'emploi (TEG) comme la part de l'augmentation du revenu professionnel qui se traduit en augmentation du revenu disponible. Si lorsque le revenu d'activité augmente de 1000 euros, le revenu disponible augmente de 600 euros, on dira que le TEG est de 60%. $ T E G = upright("Variation du revenu disponible") / upright("Variation du revenu professionnel") $

]
, 
title: 
[Taux effectif de prélèvement et taux effectif de gain à l'emploi]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
], caption: figure.caption(
position: top, 
[
]), 
kind: "quarto-callout-Astuce", 
supplement: "Tip", 
numbering: callout-numbering, 
)
<tip-teg>


Le cas d'une personne seule illustre la façon dont le système socio-fiscal assure que le travail paie mieux que l'assistance, même pour de petites durées de travail. Sans revenus d'activité, cette personne peut percevoir 851 euros de prestations sociales (559 euros de RSA et 292 euros d'allocations logement).

#figure([
#box(image("index_files/figure-typst/fig-C1A0E-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Revenu disponible d'une personne seule selon son revenu professionnel
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-C1A0E>


Si cette personne reprend un emploi rémunéré au Smic, son revenu disponible augmente, que l'emploi soit à temps partiel ou à temps plein, en dépit de la baisse du montant de prestations sociales. Avec un emploi à mi-temps, le revenu disponible est de 1 191 euros et le taux effectif de gain à l'emploi (TEG) est de 49 % (soit un taux effectif de prélèvement de 51%), ce qui veut dire que les ménages gardent en revenu disponible seulement 340 euros sur les 699 euros de salaire reçus. Cela s'explique par la baisse du montant d'aides au logement et par la perte du RSA, compensée en partie seulement par la prime d'activité. Sans la prime d'activité, le TEG ne serait que de 9%, ce qui illustre bien son rôle pour augmenter les gains à l'emploi pour un temps partiel.

Avec un emploi à temps plein, le revenu disponible double quasiment (+94%) et atteint 1656 euros (soit une hausse de 805 euros) avec un TEG de 58~%, plus élevé que pour un emploi à mi-temps en dépit de la perte des aides au logement. Là encore, la prime d'activité augmente le TEG qui ne serait que de 39~% en son absence. Si l'emploi à temps plein est rémunéré à 1,5 Smic, le niveau de vie atteint 2 016 euros (hausse de 1 165 euros) et le TEG est de 56~% car relativement à la situation d'inactivité, le travailleur perd à la fois le RSA et les aides au logement mais il n'a pas droit à la prime d'activité.

Pour un couple avec deux enfants (âgés de 5 et 8~ans) initialement sans revenu et dont un des conjoints reprend un emploi à plein-temps, le gain de revenu disponible en euros est de 845 euros, soit un gain très proche de celui du célibataire sans enfant, et par conséquent un TEG également similaire (60~% contre 58~% pour une personne seule). Mais le rôle de la prime d'activité est plus important que pour la personne seule car en son absence, le TEG ne serait que de 17~% (contre 39~%). Notons toutefois que si le gain en euros est similaire, ce couple a un revenu disponible plus important en situation d'inactivité (1 652 euros) et le gain relatif est donc moindre (+51~%). De plus, ce couple comporte davantage d'unités de consommation que le célibataire et pour une augmentation équivalente du revenu disponible, le gain en niveau de vie est deux fois plus faible que pour le célibataire sans enfant (402 euros par UC contre 804 euros).

Comparativement à une personne seule, le couple mono-actif continue à percevoir du RSA avec un emploi à mi-temps et le TEG est de 57~% uniquement grâce à la prime d'activité car il est nul pour ceux qui n'y recourent pas. Avec un emploi emploi rémunéré à 1,5 Smic, le couple mono-actif reste éligible aux aides au logement et à la prime d'activité et sont TEG est proche de celui d'une personne seule (55~%) mais contrairement à ce dernier cas, le gain à l'emploi s'explique ici en partie par la prime d'activité (le TEG est de 35~% sans la PA).

#figure([
#box(image("index_files/figure-typst/fig-C2A2ECI-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Revenu disponible d'un couple avec deux enfants selon le revenu professionnel, conjoint inactif
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-C2A2ECI>


La situation est un peu différente pour une personne en couple avec deux enfants si le conjoint est actif en emploi, rémunéré sur la base d'un Smic mensuel. Dans ce cas, le revenu disponible du couple avec deux enfants est de 2 497 euros en cas de mono-activité et la reprise d'emploi à temps plein au Smic est plus rémunératrice que pour une personne seule ou un couple mono-actif avec deux enfants car la dégressivité des aides est moindre. Cela s'explique par le fait que le couple ne perçoit pas le RSA avant la reprise d'emploi et que celle-ci se traduit uniquement par une baisse des aides au logement du montant de prime d'activité du couple. Le gain associé au second emploi à temps plein dans le couple est alors de 911 € ce qui correspond à un TEG de 65%. Contrairement aux cas précédents, la prime d'activité concourt ici à baisser le taux de gain à l'emploi du second travailleur du couple. En effet, si le ménage ne recourait pas à la prime d'activité, le TEG du second emploi serait de 78~%. Si le conjoint est salarié au Smic à temps plein, le TEG du retour à l'emploi du conjoint inactif est de 43~% pour un temps partiel (contre 57~% si le conjoint est inactif) et de 62~% pour un emploi à temps plein rémunéré au taux de 1,5 Smic. Comme pour une reprise d'emploi à temps plein au Smic, la prime d'activité réduit le TEG qui serait de 71~% et de 84~% respectivement si le ménage ne recourait pas à la prime d'activité.

#figure([
#box(image("index_files/figure-typst/fig-C2A2EC1S-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Revenu disponible couple 2 enfants, conjoint au Smic à plein-temps
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-C2A2EC1S>


Pour un même niveau de revenu du conjoint (soit le Smic à temps plein), les gains à l'emploi sont plus importants si le conjoint perçoit une allocation chômage (ou une pension d'invalidité ou de retraite) plutôt qu'un revenu professionnel. Dans ce cas, lorsque le travailleur étudié n'a aucun revenu, le couple a un revenu disponible plus faible que lorsque le conjoint est salarié (1~891~euros contre 2~497 euros) car contrairement au salaire, l'allocation chômage du conjoint n'ouvre pas droit à la prime d'activité. La reprise d'emploi a donc un effet plus faible sur le montant de prestations perçues et le gain à l'emploi pour un Smic à temps plein est de 1 090 euros, ce qui correspond à un TEG de 78%. Le taux effectif de gain est également élevé pour un emploi a mi-temps (71~%) ou à temps plein avec un salaire de 1,5 Smic (83~%).

#figure([
#box(image("index_files/figure-typst/fig-C2A2ECCH-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Revenu disponible d'un couple avec deux enfants selon le revenu professionnel, conjoint au chômage (ARE=1 smic)
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-C2A2ECCH>


== Que change la prise en compte des coûts de garde des jeunes enfants ?
<que-change-la-prise-en-compte-des-coûts-de-garde-des-jeunes-enfants>
Pour illustrer les effets du coût de la garde sur les gains à l'emploi des familles avec de jeunes enfants, nous étudions ici deux cas-types de familles avec un enfant de 1 an : une mère isolée et un couple dans lequel le conjoint travaille à temps plein rémunéré au Smic. On suppose que lorsque la mère travaille, l'enfant est gardé par une assistante maternelle, la garde onéreuse la plus courante, au prorata du temps de travail de la mère.

Le coût net de la garde est relativement modéré et représente 300 euros maximum, soit environ 10% du revenu disponible lorsque les deux conjoints sont au Smic à temps plein. Néanmoins, on peut également voir que le coût net de la garde augmente rapidement entre le mi-temps et le temps plein (il passe de 50 à 300 euros). Par conséquent, les incitations à passer du mi-temps au temps plein sont très faibles en présence d'un enfant d'âge préscolaire. Le taux de privation matérielle et sociale est un indicateur social utilisé dans l'Union européenne, défini comme la part de personnes ne pouvant pas couvrir les dépenses liées à au moins cinq éléments de la vie courante sur treize considérés comme souhaitables, voire nécessaires, pour avoir un niveau de vie acceptable.

#figure([
#box(image("index_files/figure-typst/fig-garde-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Revenu disponible d'une famille avec un enfant gardé par sa mère et/ou une assistante maternelle
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-garde>


== Disparité du taux effectif de gain à l'emploi et rôle de la prime d'activité
<disparité-du-taux-effectif-de-gain-à-lemploi-et-rôle-de-la-prime-dactivité>
Depuis le 1er janvier 2016, la prime d'activité a remplacé le RSA activité et la prime pour l'emploi. Comme les instruments qu'elle remplace, la prime d'activité vise deux objectifs~: soutenir l'offre de travail grâce à des incitations financières accrues et compléter les revenus des travailleurs ayant des revenus modestes. La prime pour l'emploi et le RSA activité ont été critiqués pour leur faible efficacité (Cahuc (2002)). Individualisée, la prime pour l'emploi versait de faibles montants à de nombreux bénéficiaires : trop faible pour être véritablement incitative, elle bénéficiait de plus à des ménages à niveau de vie intermédiaire et non aux plus modestes. Le RSA activité tenait compte de la composition et du revenu du ménage : il était davantage ciblé sur les travailleurs pauvres et créait des incitations à la reprise d'emploi substantielles et contemporaines. Néanmoins, son efficacité était minée par un non-recours élevé (68 %, voir Domingo et Pucci (2014)). Comme le RSA activité, la prime d'activité est familialisée et versée mensuellement, après une déclaration trimestrielle de ressources, et s'adresse aux travailleurs aux revenus modestes. La nouveauté est que la prime d'activité comprend un bonus individuel pour chacune des personnes en emploi dans le foyer, ce qui amplifie les incitations à la reprise d'emploi. Elle est en outre clairement identifiée comme une prestation à destination des personnes exerçant une activité, ce qui évite qu'elle apparaisse stigmatisante aux yeux de ceux qui la perçoivent. Par conséquent, le non-recours est probablement bien plus faible que celui qui était observé pour le RSA activité, bien qu'il n'y ait pas à l'heure actuelle d'estimation précise ( Hannafi #emph[et al.] (2022)). La formule de calcul de la prime d'activité pour un foyer locataire est la suivante :

$ upright("Prime d’activité du foyer ") & = upright(" Montant forfaitaire (selon la situation familiale)")\
 & + upright(" bonus d’activité individuels")\
 & - upright(" aides au logement dans la limite d’un forfait logement")\
 & - upright(" (prestations familiales + minima sociaux)")\
 & - upright(" 39 %des revenus professionnels")\
 & - upright(" 100 %des revenus non professionnels.") $

Le montant de la prime d'activité versée au foyer est nul si le résultat de ce calcul est inférieur à 15 euros.

Avec la prime d'activité, le système social et fiscal remplit bien l'objectif qui lui a été fixé : rendre le travail plus rémunérateur que l'assistance, de façon pérenne et pour toutes les reprises d'emploi. Toutefois, les gains effectifs à la reprise d'emploi sont loin d'être homogènes et le rôle de la prime d'activité pour un travailleur rémunéré au Smic diffère selon les caractéristiques de son ménage.

Pour les cas que nous avons étudiés, le taux effectif de gain pour le passage de l'inactivité à un emploi à mi-temps au Smic est plus faible que pour un emploi à temps complet. Il varie de 48% à 58% pour une personne seule selon le nombre d'enfants à charge et de 36% à 87% pour une personne vivant en couple selon le montant du revenu du conjoint, sa nature et le nombre d'enfants à charge. Le TEG le plus faible est obtenu avec 3 enfants lorsque le conjoint est salarié au Smic car la reprise d'emploi réduit à la fois les montants d'aides au logement (-174~€) et de prime d'activité (-271~€). Le gain le plus élevé est obtenu avec un conjoint chômeur et aucun enfant à charge car le couple ne bénéficie initialement que des aides au logement (89~€) et n'a donc que cela à perdre.

Le taux effectif de gain pour le passage de l'inactivité à un emploi à temps plein rémunéré au Smic est plus élevé que pour un mi-temps ( #ref(<fig-TGE>, supplement: [graphique])). Il varie de 58% à 65% pour une personne seule selon le nombre d'enfants à charge et de 52% à 94% pour une personne vivant en couple selon le montant du revenu du conjoint, sa nature, et le nombre d'enfants à charge. Comme pour l'emploi à mi-temps, le TEG le plus faible est obtenu avec 3 enfants lorsque le conjoint est salarié au Smic qui, en plus de la baisse des aides au logement et de la prime d'activité, voit également son montant de prestations familiales baisser de 97~€. Le gain le plus élevé est obtenu avec un conjoint chômeur et aucun enfant à charge qui n'a droit qu'aux aides au logement quand il n'y a qu'un emploi dans le couple.

#figure([
#box(image("index_files/figure-typst/fig-TGE-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Taux effectif de gain à l'emploi pour une reprise d'emploi au Smic à mi-temps ou à temps-plein, selon la configuration familiale
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-TGE>


L'analyse des TEG sans prime d'activité met en lumière les effets différenciés de cette prestation selon la composition du ménage, le revenu du conjoint et sa nature. Pour une personne seule, la prime d'activité a augmenté le TEG d'un emploi à plein temps au Smic pour les célibataires sans enfant et les parents isolés avec un ou deux enfants, rapprochant les gains à l'emploi de ceux d'un parent isolé avec 3 enfants qui n'y est pas éligible. Pour les personnes vivant en couple, l'impact de la prime d'activité diffère fortement selon la situation du conjoint. La prime d'activité augmente fortement le TEG du premier emploi dans le couple (conjoint sans revenu) mais réduit celui du deuxième emploi (conjoint salarié au Smic ou à 1,5 Smic).

Selon la composition de son foyer, un travailleur acceptant un emploi ne bénéficie donc pas toujours d'un taux effectif de gain à l'emploi équivalent, et la prime d'activité ne permet pas toujours d'augmenter ce gain. Le second emploi dans un couple semble ainsi découragé par rapport à ce qui prévaudrait en l'absence de prime d'activité. En outre, la prise en compte différenciée des revenus du conjoint selon leur nature peut avoir des effets indésirables. Comme la formule le montre, les revenus non professionnels du foyer sont déduits à 100%. Par conséquent, si dans un couple biactif l'un des conjoints perd son emploi pour du chômage indemnisé, non seulement il perd son bonus d'activité individuel, mais son allocation chômage est déduite intégralement, ce qui peut annuler la prime d'activité pour son conjoint resté en emploi (Pucci (2020)). En pratique, dans la plupart des cas, les foyers incluant un chômeur indemnisé (ou un retraité) ne sont pas éligibles à la prime d'activité.

D'autres limites de la prime d'activité méritent attention. Par rapport à un montant équivalent sous forme de hausse du salaire, la prime d'activité ne donne pas lieu à cotisations sociales et n'ouvre pas de droits sociaux (chômage, retraites). En augmentant l'écart de revenu entre inactivité et bas salaires, ils réduisent le gain associé à une hausse de salaire au-delà du Smic. La section suivante permet d'illustrer ce phénomène.

== La nouvelle courbe des gains marginaux à l'emploi
<la-nouvelle-courbe-des-gains-marginaux-à-lemploi>
Le graphique suivant décrit les gains associés à une hausse de salaire en fonction du niveau de salaire initial pour quatre configurations familiales. Le gain marginal à l'emploi est ce qu'il reste au foyer lorsque l'individu analysé augmente ses revenus du travail de 100 euros. Les cas-types analysés sont ceux de la personne isolée sans enfant, du couple mono-actif avec deux enfants, et d'un couple bi-actif sans enfant ou avec deux enfants dans lequel le conjoint ou la conjointe est employé au Smic à plein temps.

Le graphique montre que la prime d'activité a réduit les gains marginaux à l'emploi autour de 1 à 1,2 Smic. La courbe des gains marginaux suit maintenant une courbe en U et, à l'inverse, la courbe des taux marginaux effectifs de prélèvement, une courbe en U inversé, en contradiction avec la courbe « optimale » en U des taux marginaux, telle que décrite par Diamond (1998) ou Saez (2001). Selon ces auteurs, les taux marginaux effectifs de prélèvement les plus bas devraient s'appliquer au milieu de l'échelle de revenus, là où les individus sont les plus nombreux.

Avec les réformes visant à rendre le travail payant, les plus faibles gains à l'emploi se sont déplacés au niveau du Smic à temps complet ou juste au-dessus (#ref(<fig-gainsmarginaux>, supplement: [graphique])). Certains pourraient dire que les « trappes à inactivité » se sont transformées en « trappes à bas salaires » mais ces expressions ne sont pas appropriées puisqu'elles impliquent que les travailleurs répondent à ces plus faibles incitations. Or, il est difficile de trouver des études confirmant ces effets sur l'offre de travail en pratique. Selon le rapport Bozio et Wasmer (2024) les politiques d'exonérations sociales (ciblées autour du Smic à temps-plein), si les effets théoriques des exonérations et des primes d'activité dégressives sont soulignés régulièrement par les économistes, « la démonstration empirique de l'existence de trappes à bas salaire est néanmoins délicate », la littérature disponible en France offrant des preuves empiriques limitées.

#figure([
#box(image("index_files/figure-typst/fig-gainsmarginaux-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Gain marginaux effectifs pour une augmentation de 100 euros du revenu d'activité, selon la configuration familiale et le niveau de revenu initial
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-gainsmarginaux>


= L'emploi ne protège pas toujours de la pauvreté
<lemploi-ne-protège-pas-toujours-de-la-pauvreté>
Si l'emploi est toujours rémunérateur, il ne protège pas toujours de la pauvreté monétaire (voir #ref(<tip-tpm>, supplement: [encadré])). Ceci apparaît clairement sur cas-types mais peut se voir également par l'existence d'une pauvreté monétaire en emploi, même pour des bénéficiaires de la prime d'activité#footnote[Si la prime d'activité permet à certains foyers de franchir le seuil de pauvreté monétaire, l'analyse par cas types montre que certains foyers à bas salaire n'y sont pas éligibles. S'y ajoutent ceux qui ne recourent pas à cette prestation bien que leur niveau de vie soit inférieur au seuil de pauvreté monétaire.]. En 2022, selon l'INSEE le taux de pauvreté sur l'ensemble de la population était de 14,4%. et celui des personnes en emploi de 7,7 %. Mais en se limitant aux personnes en emploi vivant dans un ménage allocataire de la prime d'activité, ce taux atteint 15,2 % d'après nos estimations à partir de l'Enquête revenus fiscaux et sociaux de 2022. L'emploi réduit ainsi beaucoup le risque de pauvreté monétaire mais ne l'annule pas : sur les 9,1~millions de personnes vivant sous le seuil de pauvreté monétaire, 2~millions sont en emploi (INSEE).

#figure([
#block[
#callout(
body: 
[
D'après la statistique publique (INSEE, Eurostat), un individu est pauvre d'un point de vue monétaire si le niveau de vie du ménage auquel il appartient est inférieur à 60% du niveau de vie médian. La pauvreté monétaire est ainsi un concept relatif : si le niveau de vie de tous les ménages augmente de 10%, le taux de pauvreté monétaire restera inchangé. Par convention, le seuil de pauvreté monétaire est le même dans tout le pays, mais il varie au sein de l'Union européenne d'un pays à l'autre. La pauvreté monétaire est donc définie uniquement par les revenus. La seule prise en compte des différences de besoins se fait par l'échelle d'équivalence qui définit le nombre d'unités de consommation (UC) du ménage selon sa composition. Le niveau de vie ne prend donc pas en compte le coût du logement ni les besoins différenciés en transport, logement ou chauffage selon le lieu de vie. Le dernier seuil de pauvreté monétaire publié par l'Insee est de 1~288 euros par UC pour l'année 2023. Pour le comparer aux montants des prestations en 2024, nous avons appliqué à ce seuil l'inflation observée entre 2023 et juillet 2024, ce qui amène à un seuil de 1~312 euros par UC.

Le taux de privation matérielle et sociale est un indicateur social utilisé dans l'union européenne, défini comme la part de personnes ne pouvant pas couvrir les dépenses liées à au moins cinq éléments de la vie courante sur treize considérés comme souhaitables, voire nécessaires, pour avoir un niveau de vie acceptable.

]
, 
title: 
[La pauvreté monétaire et les privations matérielles et sociales]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
], caption: figure.caption(
position: top, 
[
]), 
kind: "quarto-callout-Astuce", 
supplement: "Tip", 
numbering: callout-numbering, 
)
<tip-tpm>


Le niveau de vie d'un célibataire sans enfant sans revenus d'activité et recourant à toutes les prestations est de 851 euros par UC, ce qui est inférieur de 35% au seuil de pauvreté monétaire~: son intensité de pauvreté (c'est-à-dire l'écart au seuil de pauvreté) est donc de 35% ( #ref(<fig-nivvie>, supplement: [graphique])). Un emploi à mi-temps au Smic ne lui permet pas de franchir le seuil de pauvreté (intensité de 9%). Le célibataire sans enfant franchit le seuil de pauvreté monétaire avec un Smic à plein temps même s'il ne recourt pas à la prime d'activité et son niveau de vie atteint 126% du seuil s'il y recourt. En revanche, un emploi à mi-temps ne permet pas de sortir de la pauvreté même si la prime d'activité en réduit l'intensité (de 30% avant prime à 9% après).

Une personne isolée avec enfant(s) en emploi à plein temps au Smic est au-dessus du seuil de pauvreté monétaire, qu'elle ait un enfant (125% du seuil), deux enfants (119%), ou trois enfants (124%) et elle le serait même sans la prime d'activité. Le système socio-fiscal permet donc bien aux parents isolés de sortir de la pauvreté lorsqu'ils travaillent au Smic à temps plein et la prime d'activité leur permet de dépasser largement le seuil. La prime d'activité permet même aux parents isolés d'atteindre le seuil de pauvreté avec un emploi à mi-temps au Smic.

#figure([
#box(image("index_files/figure-typst/fig-nivvie-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Niveau de vie et risque de pauvreté monétaire selon le salaire et la configuration familiale
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-nivvie>


Les revenus d'un couple mono-actif dans lequel l'un des conjoints travaille au Smic à plein temps, et l'autre conjoint est sans revenu permettent tout juste d'atteindre le seuil de pauvreté si le couple n'a pas d'enfant à condition que celui-ci recoure à la prime d'activité (#ref(<fig-pauvrete>, supplement: [graphique])). À ce niveau de revenus, le système social ne compense pas entièrement la charge des enfants, et le niveau de vie des couples mono-actifs avec enfants est légèrement plus faible quand ils ont des enfants que quand ils n'en ont pas. L'intensité de la pauvreté monétaire est ainsi de 7% s'ils ont un enfant, 9% avec deux enfants, et 5% avec trois enfants.

Les couples biactifs avec deux emplois au Smic à temps plein ont un revenu disponible avant prime d'activité supérieur au seuil de pauvreté et dépassent largement ce seuil avec la prime. Le système socio-fiscal ne compense que partiellement la charge des enfants telle qu'elle est appréhendée par les unités de consommation. Un couple biactif au Smic recourant à la prime d'activité a ainsi un niveau de vie équivalent à 153% du seuil de pauvreté s'il n'a pas d'enfant, 135% du seuil de pauvreté s'il en a un, 124% avec deux enfants et 117% avec trois.

Nous avons jusqu'ici utilisé des cas-types, mais les graphiques ci-dessous montrent que ces cas-types se traduisent dans des situations moyennes. Les graphiques représentent les taux de pauvreté monétaire (gauche) et de privation matérielle et sociale (droite) des individus selon leur revenu salarial mensuel (en tranche de Smic) et leur situation conjugale (en couple ou célibataire). On voit que le taux de pauvreté monétaire baisse nettement lorsque les revenus salariaux augmentent. Cette baisse de la pauvreté est liée directement à l'augmentation des salaires (composantes du niveau de vie), mais aussi à des caractéristiques plus favorables.

#figure([
#box(image("index_files/figure-typst/fig-pauvrete-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Taux de pauvreté et taux de privation matérielle selon la tranche de revenu salarial et la configuration familiale
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-pauvrete>


Le taux de privation matérielle et sociale baisse également lorsque le salaire augmente, mais la baisse est plus franche seulement à partir du Smic. Cela suggère qu'il existe un coût à travailler de faibles nombres d'heures et que ce coût compense la hausse du salaire net et du revenu disponible. Ce coût peut être lié au transport ou à la garde d'enfants.

Si l'hypothèse du coût pour les emplois à temps partiel est juste, il existe deux réponses possibles en termes de politiques publiques : inciter de façon monétaire les individus pour qu'ils acceptent ces emplois ou favoriser une norme d'emploi à temps complet. Avant d'exposer nos recommandations (section 4), on peut noter qu'inciter au temps-partiel ou très-partiel, que ce soit côté entreprises ou côté individus, est potentiellement coûteux socialement en présence de coûts fixes à l'emploi (par exemple sous la forme de transports). Cette politique peut par exemple pousser un individu à accepter un emploi à temps très partiel et éloigné de chez lui. Or, ce type d'emploi ne sert pas toujours de marchepied et peut réduire les efforts de recherche et la probabilité d'obtenir un emploi de meilleure qualité (voir par exemple Autor et Houseman (2006)).

= Le minimum garanti est souvent en deçà du seuil de très grande pauvreté
<le-minimum-garanti-est-souvent-en-deçà-du-seuil-de-très-grande-pauvreté>
La reprise d'emploi est toujours rémunératrice mais l'intensité de la pauvreté des ménages sans emploi est forte.

Dans les cas-types étudiés, les revenus d'assistance procurent un niveau de vie inférieur au seuil de pauvreté à 60 %, et même inférieur au seuil de grande pauvreté à 40 % pour les couples et les personnes seules ( #ref(<fig-ndvminimum>, supplement: [graphique])).

#figure([
#box(image("index_files/figure-typst/fig-ndvminimum-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Niveau de vie (en euros par uc) du revenu d'assistance et des allocations logement selon la configuration familiale, pour un foyer sans revenu primaire
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-ndvminimum>


Le niveau de vie des ménages sans revenus d'activité est faible. Il a décru dans le temps et relativement aux autres revenus. Depuis 1990, le niveau du minimum social en direction des personnes d'âge actif a ainsi progressé bien moins vite que le niveau du minimum vieillesse (ASPA) ou de l'allocation adulte handicapée (AAH) (voir graphique).

En 1989, la loi instaurant le RMI a pour principal objectif de donner un minimum social pour les personnes valides d'âge actif. Si l'objectif est principalement distributif, le législateur a néanmoins voulu préserver les incitations à travailler en fixant le niveau du RMI à 50 % du SMIC à temps plein (mais en l'indexant sur l'inflation et non pas sur le niveau du Smic ou du salaire moyen par tête). Les débats font alors apparaître la volonté que le norme d'emploi soit le temps complet. Dans les années 1990, le nombre d'allocataires augmente rapidement et atteint un niveau non anticipé par les décideurs publics : de 500~000 allocataires en 1990, ce nombre dépasse le million en 1996. Face à cette montée rapide, le discours sur les «~trappes à pauvreté~» se répand. En 2001, l'introduction de la prime pour l'emploi (PPE) est une première réponse à ce discours. La PPE étant accusée d'être mal ciblée et de pénaliser les emplois à temps partiel, le RSA activité prend la relève en 2009 et permet de garantir que le revenu disponible d'un foyer augmente lorsque ses revenus d'activité augmentent, même à temps partiel ou très partiel. Il est ensuite remplacé par la prime d'activité en 2015, revalorisée lors de la crise des gilets jaunes pour les salaires proches du Smic. Durant cette période d'attention aux gains à l'emploi et à la pauvreté laborieuse, le montant de base du RSA est peu revalorisé ( #ref(<fig-minima>, supplement: [graphique])).

Malgré l'augmentation des gains à la reprise d'emploi via le creusement de l'écart entre le RSA et le SMIC et la montée en charge des compléments de revenus pour travailleurs pauvres, la part d'allocataires du RSA dans la population d'âge actif a augmenté, passant de 3,0% en 2008 à 4,1% en 2022. La réduction du niveau de vie relatif du RSA n'a donc pas eu d'effets visibles en termes de baisse du nombre d'allocataires.

#figure([
#box(image("index_files/figure-typst/fig-minima-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Evolution des mimina sociaux et du Smic horaire, base 100 en 1990
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-minima>


= Peut-on dépasser les dilemmes du système social ?
<peut-on-dépasser-les-dilemmes-du-système-social>
Le système social et fiscal remplit bien l'objectif qui lui a été fixé depuis la mise en place en 2009 du RSA, et en particulier de son volet activité : rendre le travail plus rémunérateur que l'assistance. Mais avoir un emploi rémunéré au Smic n'est pas un gage de sortie de la pauvreté, et vivre sans emploi implique souvent d'être dans une situation de grande pauvreté. Le système ne remplit donc pas tous les objectifs fixés par la stratégie nationale de prévention et de lutte contre la pauvreté. Est-il possible d'y parvenir en modifiant les barèmes du RSA et de la prime d'activité ? Nous explorons ici les effets potentiels d'une hausse du socle (RSA et forfait de prime d'activité) ou d'un ciblage de la prime d'activité sur le temps partiel et discutons des limites d'un soutien aux bas salaires par une hausse du Smic ou de la prime d'activité.

== Avantages et limites d'une augmentation du socle
<avantages-et-limites-dune-augmentation-du-socle>
Il est possible de concilier les trois objectifs - travail rémunérateur, travail permettant de sortir de la pauvreté et niveau de vie minimum suffisamment élevé - en relevant le montant des prestations de solidarité (RSA et aides au logement) et en gardant un minimum d'incitations. En effet, si les personnes en emploi restent pauvres malgré les allocations et les incitations… c'est simplement qu'elles partent de trop bas. Le socle RSA pourrait être revalorisé de telle sorte qu'un foyer sans emploi atteigne 50 % du niveau de vie médian, soit environ 1 090 euros pour une personne isolée sans enfant et 2 300 euros pour un couple avec deux enfants. Cela impliquerait que le montant du RSA et le forfait de prime d'activité avant forfait logement soient de 900 euros#footnote[Le niveau requis est estimé pour la personne seule allocataire des aides au logement en zone 2 en zone 2 (villes de plus de 100 000 habitants).]. Pour que le taux de sortie de la prime d'activité reste inchangé (soit 1,45 Smic pour une personne seule), il faudrait en parallèle diminuer le taux de cumul avec les revenus professionnels (45% au lieu de 61 %). Cette réforme permettrait aux couples avec deux enfants de franchir le seuil de pauvreté monétaire avec un seul emploi au Smic à temps plein.

Cette réforme est celle qui permettrait d'atteindre simultanément les trois objectifs de manière cohérente. Elle est également la plus juste dans la mesure où elle réduirait fortement les inégalités avec, probablement, de très faibles coûts en termes d'efficacité et d'emploi (voir par exemple Bargain et Vicard (2014) et Simonnet et Danzin (2014)). Mais elle est aussi la plus coûteuse. Comme le montre notre simulation (voir #ref(<tip-simul>, supplement: [encadré])), augmenter le socle à 900 euros avec une légère baisse du taux de cumul de la prime d'activité aurait un coût d'environ 24~milliards d'euros pour les pouvoirs publics, dont 11~milliards de RSA et 13~milliards de prime d'activité. Le dilemme entre redistribution et incitation est en fait un triangle d'incompatibilité entre redistribution, incitations monétaires et coût budgétaire Bozio et Grenet (2017)).

Une solution permettant de réduire le coût serait de réduire bien plus fortement le taux de cumul entre prestation d'assistance et revenus du travail, de sorte que les bénéfices de la hausse soient ciblés sur les plus pauvres. Nous avons simulé un scénario dans ce sens (taux de cumul de 35% de la prime d'activité au lieu de 45 %) qui présente l'inconvénient majeur de faire des perdants très bas dans l'échelle de revenus tout en réduisant drastiquement les gains à l'emploi.

== Soutenir les emplois à temps partiel ou promouvoir la norme du temps plein ?
<soutenir-les-emplois-à-temps-partiel-ou-promouvoir-la-norme-du-temps-plein>
Faut-il cibler les compléments de revenus pour les travailleurs à bas revenu au niveau du temps partiel ou du temps-plein ? Posé comme cela, le problème est insoluble : pour protéger de la pauvreté, il vaut mieux inciter au temps-plein ; mais pour réduire directement la pauvreté laborieuse, il vaut mieux donner plus aux travailleurs à temps-partiel, qui ont des niveaux de vie plus faibles, souvent sous le seuil de pauvreté. Le débat sur la place du temps-partiel dans le dispositif de compléments de revenus pour travailleurs à bas revenus date des débuts de la prime pour l'emploi en 2001 (voir notamment Cahuc, 2002). Redistribution et incitation sont des objectifs non seulement inconciliables mais contradictoires. La redistribution implique de réduire les écarts de revenus disponibles entre non-emploi, temps partiel, temps-plein au Smic et emploi mieux rémunéré. L'incitation implique de les maintenir ou de les augmenter. Il est possible de dépasser le dilemme localement (en augmentant le revenu disponible par les transferts à la fois à temps-partiel et à temps-plein au Smic), mais le problème est alors déplacé plus haut, à l'endroit où la prestation devient dégressive. On parle aujourd'hui de trappes à bas salaires (voir le rapport Bozio et Wasmer (2024)). A la redistribution et l'incitation, s'ajoute un autre objectif : rémunérer le « mérite ». Il est probable que beaucoup d'acteurs aient cet objectif en tête lorsqu'ils défendent l'idée que le « travail doit payer », mais dans cet optique, faut-il cibler les gains sur le temps partiel ou sur le temps plein ? Deux philosophies s'opposent. Selon la première, le travail à temps plein doit payer. Il faudrait créer une norme de temps plein, forme d'emploi la plus propice pour réduire la pauvreté. A la création du RMI, l'écart entre le RMI et le Smic a été calculé sur la base d'un temps plein. Initialement, le montant du RMI a été fixé à 50% du Smic, ce qui peut être interprété en termes incitatifs ou de mérite. Selon la seconde philosophie, chaque heure de travail doit payer, c'est-à-dire que chaque heure travaillée mérite une hausse du revenu disponible. Toutefois, la volonté de créer un écart de revenus à la fois entre l'inactivité et le mi-temps et entre le mi-temps et le temps-plein crée une pression à la baisse sur le niveau des revenus d'assistance. En 1989, la norme d'emploi était le CDI à temps plein. Le RMI était différentiel par rapport à un montant forfaitaire fixe. Après période d'intéressement temporaire\[2\], chaque euro de revenus supplémentaires se déduisait à 100% du revenu versé. Cela veut dire qu'à terme une personne seule reprenant un emploi à mi-temps n'avait aucun gain financier par rapport au revenu d'assistance. Les gains étaient concentrés entre le mi-temps et le temps plein. À cette époque, malgré l'absence de gain financier (passé la période d'intéressement), il y avait tout de même des reprises d'emploi à temps partiel et même du cumul durable entre RMI et revenus professionnels, signe que les personnes concernées reconnaissaient les aspects positifs de l'emploi au-delà du revenu. À l'heure actuelle, la combinaison RSA-PA implique que le montant versé est différentiel par rapport à un revenu garanti qui augmente avec les revenus professionnels du foyer selon deux mécanismes : le taux de cumul et les bonus individuels. Il en résulte que le soutien relatif aux emplois à temps partiel a fortement augmenté, ce qui dénote une attention portée davantage sur les symptômes de la pauvreté laborieuse que sur les incitations à sortir de la pauvreté par l'emploi à temps complet. Faut-il revenir au système prévalent de 1989 jusqu'à la création du RSA en 2009 ? Ce système permettrait à la fois d'avoir un socle plus élevé et de réaffirmer le temps plein comme norme de travail et de renforcer cette norme non pas avec des mesures qui visent les travailleurs, mais avec une régulation du temps de travail limitant le nombre de postes à pourvoir à temps partiel (voir conclusion).

== Augmenter les gains à l'emploi par la hausse du Smic ou grâce à la prime d'activité ?
<augmenter-les-gains-à-lemploi-par-la-hausse-du-smic-ou-grâce-à-la-prime-dactivité>
Faut-il privilégier le soutien aux bas-salaires via le Smic et les salaires ou via la prime d'activité et ses bonus individuels qui ont été renforcés à la suite de la crise des gilets jaunes ? Pour répondre à cette question, il faut rappeler en quoi hausse du Smic et prime d'activité ne sont pas équivalents car la prime d'activité n'est pas un salaire :

--- Le salaire est totalement individualisé : le bénéfice de la prime pour un travailleur à bas salaire dépend de la composition de sa famille, du montant et de la nature des revenus de son conjoint

--- Le salaire est plus prévisible pour les travailleurs. Ils peuvent difficilement anticiper le montant de la prime d'activité compte tenu de son mode de calcul et des risques d'indus et de suspension/rappels

--- le salaire procure des droits sociaux : le taux de remplacement au chômage ou à la retraite est réduit pour les bénéficiaires de la prime si l'on raisonne en revenus nets.

Avec le système actuel, les pouvoirs publics poursuivent deux objectifs : lutter contre la pauvreté et augmenter les gains à l'emploi dans une logique de mérite. Or, pauvreté et niveaux de vie sont par construction familialisés tandis que le salaire et le mérite sont par construction individuels (Ponthieux (2009)). L'hybridation de ces deux logiques, la lutte contre la « pauvreté laborieuse », crée des situations paradoxales. Par exemple, dans le système actuel, si dans un couple biactif l'un des conjoints perd son emploi et touche des allocations chômage, alors cela entraîne la plupart du temps la perte de la prime d'activité pour le couple car les allocations chômage sont intégralement déduites du revenu garanti du foyer. La perte d'emploi annule ainsi le droit à la prime du conjoint mais aussi les éléments de primes liés à la charge d'enfants. Le paradoxe est que si l'on accorde un poids plus important à l'objectif de réduction de la pauvreté laborieuse qu'à celui de la réduction de la pauvreté, alors il est préférable que certains pauvres ne travaillent pas. Résoudre le paradoxe nécessite de démêler les vrais objectifs afin de les rendre cohérents. Les objectifs sont les suivants. Premièrement, réduire la pauvreté et les inégalités de niveau de vie. Deuxièmement, augmenter l'emploi pour réduire le coût public de la pauvreté.

Selon le principe de Tinbergen, lorsqu'il y a deux objectifs distincts, ici la lutte contre la pauvreté et les gains à l'emploi, il faut affecter à des instruments distincts la poursuite de chacun de ces objectifs. Dans cette optique, on pourrait considérer que le RSA et une prime d'activité entièrement familialisée (sans bonus individuels) permettent de lutter contre la pauvreté et les inégalités de niveau de vie mais n'ont pas pour objectif d'augmenter les gains à l'emploi. Dans ce cas, il faudrait étendre le bénéfice de la prime d'activité aux chômeurs (les travailleurs sans emploi). Pour ce qui est de l'objectif de soutien aux bas salaires, le Smic, associé à la norme du temps plein, doit être l'instrument monétaire privilégié. Si l'objectif est la lutte efficiente contre la pauvreté, alors il faut éviter que les entreprises puissent se reposer sur le système social pour proposer des emplois qui ne seraient pas viables sans soutien public.

== L'aide à sortir de l'assistance ne doit-elle concerner que le travail ?
<laide-à-sortir-de-lassistance-ne-doit-elle-concerner-que-le-travail>
Le débat sur les gains à l'emploi, les taux de prélèvements et les incitations ne concerne aujourd'hui que le travail. Cela montre l'importance du « mérite » associé au travail dans le débat public, indépendamment des difficultés rencontrées par certains pour accéder à l'emploi. Les plus pauvres peuvent cumuler (partiellement) leurs revenus du travail avec leurs prestations sociales, mais ce n'est pas le cas pour les autres ressources comme les revenus de remplacement (retraite, chômage), les pensions alimentaires, les héritages et les dons, les gains aux jeux, les loyers reçus pour un logement loué, la valeur locative des logements non loués (!), les revenus des capitaux, et les revenus fictifs des biens non productifs, comme les contrats d'assurance-vie, imputés à hauteur de 3% de leur valeur marchande. Nombre de ces ressources ne sont pas comprises dans la base fiscale des plus aisés, le Conseil constitutionnel ayant même tranché contre la prise en compte de revenus non effectifs (la valeur locative de logements non loués ne peut rentrer dans le revenu au titre de l'imposition sur le revenu). Le RSA, prestation d'assistance, suit une logique de subsidiarité : le demandeur doit démontrer avoir fait valoir tous ses droits, aux autres prestations sociales et créances alimentaires, et même aux revenus de ses biens non utilisés. Tous les revenus non professionnels sont déductibles à 100% du RSA et de la prime d'activité : un don de 100 euros, le revenu tiré d'une chambre à louer ou d'une petite épargne. Cette logique crée des situations impossibles pour les allocataires, même sincères. S'ils reçoivent une aide familiale dans une situation d'urgence, une chaudière qui tombe en panne, un enfant malade, un évènement à l'autre bout de la France, ils doivent déclarer cette aide qui sera entièrement déduite de l'allocation versée. La conséquence est qu'il y aura plus de fraudes détectées chez les personnes vulnérables, qui contournent, parfois involontairement, une technocratie dont la rigueur est asymétrique entre les plus pauvres et les plus aisés. Ceci est d'autant plus problématique que le calcul de la base ressource à l'euro près s'applique à une prestation faible versée à des foyers pauvres ou modestes. Il peut en résulter un phénomène de spirale de la pauvreté puisque le moindre coup de pouce, le moindre effort d'épargne voient leurs effets annulés par le mode de calcul du RSA et de la prime d'activité. Une solution serait de rendre le calcul de la prestation plus bienveillant en mettant en place un abattement sur l'ensemble des petits revenus (et non pas seulement les revenus du travail) : par exemple, les 450 premiers euros par trimestre (150 euros par mois) ne seraient pas pris en compte dans le calcul de la prestation, quelle que soit leur origine. Un avantage d'une telle réforme serait que le demandeur de l'allocation ayant des petits revenus n'aurait pas à détailler leur origine lors de la demande, il cocherait simplement la case « ressources inférieures à 450 euros ». Cette réforme pourrait être réalisée à coût constat en réduisant un peu le taux de cumul avec les revenus professionnels (58,5% au lieu de 61% actuellement). Un tel système réduirait la peur de se tromper, la peur des indus à rembourser, et donc le non-recours. Les premiers revenus d'activité seraient gardés à 100 % par les travailleurs, ce qui répond aussi à la problématique des coûts fixes à la reprise d'emploi. Au-delà de l'abattement, le taux de cumul des revenus d'activité et de la prime d'activité pourrait être abaissé pour garder les gains à la reprise d'emploi à plein temps constants par rapport à la situation actuelle. Si l'objectif est que les allocataires des minima sociaux en sortent par le haut, il faut aussi éviter d'annuler le moindre coup de pouce ou coup de chance.

#figure([
#block[
#callout(
body: 
[
Nous simulons deux réformes illustratives pour donner des ordres de grandeur concernant le coût de ce type de réformes ainsi que la répartition des foyers gagnants ou perdants. Pour cela, nous utilisons le modèle de microsimulation sociale et fiscale INES développé par l'INSEE, la DREES et la CNAF. La version utilisée d'INES simule la législation 2022 sur les données de l'Enquête Revenus fiscaux et sociaux (ERFS) 2020 actualisées à l'aide des dernières données démographiques et économiques disponibles. Nos simulations font l'hypothèse d'un taux de non-recours inchangé (en masse financière)5. Les deux réformes simulées s'appuient sur les points évoqués dans la section précédente. \
La première réforme consiste simplement à augmenter le socle du RSA et à baisser le taux de cumul de la prime d'activité. Cela répond directement au point 4.1. Une telle réforme serait moins favorable aux incitations à temps-partiel (les travailleurs à temps-partiel ne seraient pas perdants mais l'écart avec les revenus d'assistance serait réduits). Cette réforme est justifiée si on prend au sérieux la lutte contre la grande pauvreté, si on souhaite verser un revenu minimum un peu plus décent, et/ou si l'on considère que les incitations ne jouent pas ou peu à ce niveau-là, les obstacles à la reprise d'emploi étant autres que les faibles gains. Le problème de cette réforme est son coût. Fixer le socle à 900 euros par mois pour une personne seule, permettant d'atteindre le seuil de pauvreté à 50%, pourrait se faire sans décaler le point de sortie de la prime d'activité en diminuant le taux de cumul de la prime d'activité de 61~% à 45~%. La combinaison de la hausse du socle et de la baisse du taux de cumul coûterait jusqu'à 30~milliards d'euros en plein recours et 24~milliards d'euros à taux de recours inchangé. Par construction, une telle réforme ne ferait presque pas de perdants : presque tous les bénéficiaires du RSA et de la prime d'activité actuels seraient gagnants mais il n'y aurait pas de gagnants au-delà. D'ailleurs le coût en termes de prime d'activité (13~milliards à recours inchangé) serait supérieur à celui du RSA (11~milliards). Par construction les plus gros gains sont concentrés sur le premier décile (avec une variation moyenne de revenu de 260 euros mensuels) puis sont très fortement dégressifs (170 euros pour les foyers du 2e décile des niveaux de vie, et 60 € pour un niveau de vie médian). La deuxième réforme consiste à changer le mécanisme de cumul. Afin de permettre aux foyers allocataires de bénéficier de coups de pouces et de simplifier les déclarations, nous permettons un cumul à 100% jusqu'à 150 euros par mois (en pratique 450 € par trimestre) de l'ensemble des revenus hors prestations familiales et sociales (salaires, revenus de remplacement - chômage, retraites, dons, revenus du patrimoine financier et foncier). Le mécanisme se rapprocherait des mécanismes d'#emph[earnings disregards,] relativement communs dans les pays anglo-saxons. L'abattement de revenus peut être justifié par des coûts fixes de reprise d'emploi ou pour minimiser les démarches administratives pour des revenus très faibles. En gardant la même pente de prime d'activité, la réforme ne ferait que des gagnants et le coût pour les finances publiques serait de 2,2~milliards en plein recours et 1,8~milliard à taux de non-recours inchangé. Pour atteindre la neutralité budgétaire, il conviendrait de réduire le taux de cumul de la prime d'activité de 61 à 58,5%. Cette réforme ferait quelques gagnants en bas de l'échelle des revenus (9% des ménages sont gagnants) et des perdants au-delà (16% des ménages perdants). Selon notre microsimulation, les gagnants se situeraient surtout dans le 1er décile (gain moyen de 19 euros mensuels sur l'ensemble des ménages du décile), tandis que les perdants se situeraient dans le 4e décile (perte de 8 euros mensuels sur l'ensemble des ménages du décile).

]
, 
title: 
[Simulation de deux réformes]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
], caption: figure.caption(
position: top, 
[
]), 
kind: "quarto-callout-Astuce", 
supplement: "Tip", 
numbering: callout-numbering, 
)
<tip-simul>


= Conclusion : dépasser les dilemmes par la redistribution réglementaire ?
<conclusion-dépasser-les-dilemmes-par-la-redistribution-réglementaire>
La réforme consistant à augmenter le socle nous paraît la plus juste dans la mesure où elle réduit fortement les inégalités, avec -probablement- de très faibles coûts en termes d'efficacité et d'emploi. Le problème principal d'une telle réforme est son coût, 24~milliards d'euros à recours inchangé. On peut considérer que ce montant est le coût de l'injustice du système actuel tout en reconnaissant qu'avec un tel budget, il pourrait être possible de faire mieux pour la population concernée qu'en réformant le RSA et la prime d'activité. Il existe en effet une autre solution permettant de dépasser les dilemmes monétaires exposés dans ce document. On peut parler de redistribution réglementaire ou de redistribution des droits. De même que l'augmentation du Smic est potentiellement peu ou pas coûteuse, jusqu'à un certain niveau, en termes de finances publiques, c'est également le cas du renforcement des droits des travailleurs les plus précaires, par exemple en renforçant le droit au passage au temps plein ou en pénalisant la fragmentation journalière du travail. Devetter et Valentin (2025) montrent que le Smic n'est pas une protection suffisante contre la pauvreté des travailleurs, en raison de la prévalence du temps partiel contraint dans des métiers dont le taux horaire est faible : plus de 20% des salariés ont un revenu salarial annuel inférieur au niveau du Smic à temps plein. Le seuil de bas salaire mensuel (défini à deux tiers du salaire médian) étant proche du Smic mensuel, les bas salaires manquent d'heures dans le mois par rapport à un temps plein. Les métiers les plus touchés par les bas salaires sont les métiers du care (assistantes maternelles, aides à domicile) qui comptent 66% de bas salaires, les métiers du nettoyage (47%), les métiers de l'hôtellerie-restauration (50%). Ces trois secteurs concentrent 43% des bas-salaires mensuels. Or ces professions cumulent une forte amplitude et une faible densité de la journée de travail. Une réglementation plus protectrice permettrait de réduire le recours au temps partiel, ce qui pourrait même limiter les besoins en termes de prime d'activité. Le coût serait reporté sur les consommateurs de ces services. Le service de nettoyage, l'aide aux personnes et la restauration n'étant pas délocalisables, les risques sur l'emploi seraient limités.

#heading(level: 1, numbering: none)[Bibliographie]
<bibliographie>
#block[
#block[
Allegre G. (2024). «~#link("https://sciencespo.hal.science/hal-04395802")[Les nouvelles lois sur les pauvres (1989-2023) : L'injonction au travail, au risque de la pauvreté ?]~», #emph[Document de travail OFCE], n° 2024-01.

] <ref-allegre2024lois>
#block[
Autor D., Houseman S. (2006). «~#link("https://ideas.repec.org/h/upj/uchaps/snhrsf06.html")[Temporary Agency Employment: A Way Out of Poverty? in Working and Poor: How Economic and Policy Changes Are Affecting Low-Wage Workers]~», p.~312‑337.

] <ref-autorhouseman2006>
#block[
Bargain O., Vicard A. (2014). «~#link("https://doi.org/10.3406/estat.2014.10247")[Le RMI et son successeur le RSA découragent-ils certains jeunes de travailler ? Une analyse sur les jeunes autour de 25 ans]~», #emph[Economie et Statistique], #emph[467], n° 1, p.~61‑89.

] <ref-bargainvicard2014>
#block[
Bozio A., Grenet J. (2017). #emph[#link("https://pjse.hal.science/hal-01784362")[Economie des politiques publiques]], La Découverte (Repères).

] <ref-boziogrenet2017>
#block[
Bozio A., Wasmer E. (2024). «~#link("https://www.strategie-plan.gouv.fr/files/files/Publications/Rapport/rapport_vffff_241003.pdf")[Les politiques d exoneration de cotisations sociale : une inflexion necessaire]~», Research Report, France Strategie.

] <ref-boziowasmer2024>
#block[
Cahuc P. (2002). «~#link("https://doi.org/10.3406/rfeco.2002.1513")[A quoi sert la prime pour l'emploi ?]~», #emph[Revue Française d'économie], #emph[16], n° 3, p.~3‑61.

] <ref-cahuc2002aquoisert>
#block[
Devetter F.-X., Valentin J. (2025). «~#link("https://shs.cairn.info/revue-informations-sociales-2025-1-page-60?lang=fr")[Le smic protège-t-il suffisamment des basses rémunérations ?]~», #emph[Informations Sociales], #emph[213], n° 1, p.~60‑68.

] <ref-devettervalentin2025IS>
#block[
Diamond P. (1998). «~#link("http://www.jstor.org/stable/116819")[Optimal Income Taxation: An Example with a U-Shaped Pattern of Optimal Marginal Tax Rates]~», #emph[The American Economic Review], #emph[88], n° 1, p.~83‑95.

] <ref-diamond1998>
#block[
Domingo P., Pucci M. (2014). «~#link("https://doi.org/10.3406/estat.2014.10249")[Impact du non-recours sur l'efficacité du RSA activité seul]~», #emph[Economie et Statistique], #emph[467], n° 1, p.~117‑140.

] <ref-domingopucci2014>
#block[
Hannafi C., Le Gall R., Omalek L., Marc C. (2022). «~#link("https://hal.science/hal-03618416")[Mesurer régulièrement le non-recours au RSA et à la prime d'activité : méthode et résultats]~», Dossiers de la Drees 92, DREES .

] <ref-hannafi2022drees>
#block[
Ponthieux S. (2009). «~#link("https://www.insee.fr/fr/statistiques/1380802")[Les travailleurs pauvres comme catégorie statistique]~», #emph[Document de travail INSEE], n° FO902.

] <ref-ponthieux2009>
#block[
Pucci M. (2020). «~#link("https://www.ofce.sciences-po.fr/blog/la-prime-dactivite-nest-pas-du-salaire-elle-amplifie-la-perte-de-revenu-a-la-suite-dun-licenciement/")[La Prime d'activité n'est pas du salaire : elle amplifie la perte de revenu Ã la suite d'un licenciement]~», #emph[Blog de l'OFCE].

] <ref-pucci2020blogpa>
#block[
Saez E. (2001). «~#link("https://doi.org/None")[Using Elasticities to Derive Optimal Income Tax Rates]~», #emph[The Review of Economic Studies], #emph[68], n° 1, p.~205‑229.

] <ref-saez2001>
#block[
Sicsic M. (2023). «~#link("https://doi.org/None")[L'élasticité de l'offre de travail et des revenus dans la littérature. Une analyse comparative des méthodes et des résultats sur données microéconomiques]~», #emph[Revue de l'OFCE], #emph[0], n° 4, p.~5‑40.

] <ref-sicsic2023elas>
#block[
Simonnet V., Danzin E. (2014). «~#link("https://doi.org/10.3406/estat.2014.10248")[L'effet du RSA sur le taux de retour Ã l'emploi des allocataires. Une analyse en double diffÃ©rence selon le nombre et l'Ã¢ge des enfants]~», #emph[Economie et Statistique], #emph[467], n° 1, p.~91‑116.

] <ref-simmonetdanzin2014>
] <refs>



