dot <- grViz("
digraph {
  graph [rankdir=TB, splines=true, nodesep=0.5, ranksep=0.6]
  node  [shape=box, style=\"rounded,filled\",
         fontsize=22, fontname=\"Helvetica, Arial\",
         color=\"#2f3b52\", fontcolor=\"#1f2937\",
         penwidth=1.2, fillcolor=\"#f7f9fc\", margin=0.06]
  edge  [color=\"#6b7280\", arrowsize=0.8]

  // Nodes -------------------------------------------------------------

  A [width=6, label=<
    <TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLPADDING=\"6\">
      <TR><TD><B>1) Build OSM cycling networks</B></TD></TR>
      <TR><TD>Extract 2016-01-01 and 2024-01-01;<BR/>
              classify cycling vs non-cycling segments</TD></TR>
    </TABLE>
  >]

  B [width=6, label=<
    <TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLPADDING=\"6\">
      <TR><TD><B>2) Detect OSM network change</B></TD></TR>
      <TR><TD>Geometric differencing 2015 to 2023;<BR/>
              flag ADD and REMOVE;<BR/>
              drop short segments and realignments</TD></TR>
    </TABLE>
  >]

  C [width=6, label=<
    <TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLPADDING=\"6\">
      <TR><TD><B>3) Design stratified GSV sample</B></TD></TR>
      <TR><TD>Stratify tracts by density x centrality (3x3);<BR/>
              sample 6 tracts per stratum;<BR/>
              length weighted ADD / REMOVE / NONCI segments</TD></TR>
    </TABLE>
  >]

  D [width=7, label=<
    <TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLPADDING=\"6\">
      <TR><TD><B>4) Inspect and code GSV</B></TD></TR>
      <TR><TD>Anchor years 2015 and 2023 (+/-1 year);<BR/>
              code 1 / 0 / NA at sampled points;<BR/>
              compare GSV patterns with OSM change</TD></TR>
    </TABLE>
  >]

  E [width=5, label=<
    <TABLE BORDER=\"0\" CELLBORDER=\"0\" CELLPADDING=\"6\">
      <TR><TD><B>5) Evaluate OSM performance</B></TD></TR>
      <TR><TD>Derive TP / FP / FN;<BR/>
              compute precision, recall, F1<BR/>
              with 95 percent confidence intervals</TD></TR>
    </TABLE>
  >]

  // Clusters: the two main components --------------------------------

  subgraph cluster_osm {
    label = \"OSM temporal differencing\";
    labelloc = \"t\";
    fontsize = 20;
    fontname = \"Helvetica, Arial\";
    style = \"rounded,dashed\";
    color = \"#CBD5E1\";
    A; B;
  }

  subgraph cluster_gsv {
    label = \"Stratified GSV validation\";
    labelloc = \"t\";
    fontsize = 20;
    fontname = \"Helvetica, Arial\";
    style = \"rounded,dashed\";
    color = \"#CBD5E1\";
    C; D; E;
  }

  // Edges -------------------------------------------------------------

  A -> B -> C -> D -> E
}
")

svg_txt <- export_svg(dot)
rsvg_svg(charToRaw(svg_txt), file = "figs/osm_gsv_flowchart.svg")
rsvg_png(charToRaw(svg_txt), file = "figs/osm_gsv_flowchart.png",
         width = 1800, height = 1000)