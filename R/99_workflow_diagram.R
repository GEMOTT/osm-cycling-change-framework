# ================================================================
# 99_workflow_diagram.R
# Create/update a workflow diagram of the pipeline steps and data products.
#
# Inputs:  pipeline definitions
# Outputs: workflow diagram file
# ================================================================

dot <- grViz("
digraph {
  graph [rankdir=TB, bgcolor='white', splines=ortho, nodesep=0.2, ranksep=0.28, pad=0.05]

  node [
    shape=box,
    fixedsize=true,
    width=7.4,
    height=1.45,
    style='rounded,filled',
    fontname='Helvetica',
    fontsize=16,
    color='#1d4e89',
    fillcolor='#f8fbff',
    penwidth=1.6,
    margin=0.08
  ]

  edge [color='#111827', penwidth=1.1, arrowsize=0.65]

  det [
    shape=plain,
    fixedsize=false,
    label=<
      <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
        <TR><TD><FONT COLOR='#1d4e89'><I>Detection (Steps 1-2)</I></FONT></TD></TR>
      </TABLE>
    >
  ]

  val [
    shape=plain,
    fixedsize=false,
    label=<
      <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
        <TR><TD><FONT COLOR='#1d4e89'><I>Validation (Steps 3-5)</I></FONT></TD></TR>
      </TABLE>
    >
  ]

  A [label=<
    <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
      <TR><TD><FONT POINT-SIZE='16'><B>1. Build OSM cycling-infrastructure networks</B></FONT></TD></TR>
      <TR><TD>Extract 2016-01-01 and 2024-01-01;<BR/>representing proxy conditions for 2015 and 2023;<BR/>classify cycling vs non-cycling segments</TD></TR>
    </TABLE>
  >]

  B [label=<
    <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
      <TR><TD><FONT POINT-SIZE='16'><B>2. Detect OSM network change</B></FONT></TD></TR>
      <TR><TD>Geometric differencing 2015 to 2023;<BR/>define ADD, REMOVE and NONCYC pools;<BR/>drop short segments and realignments</TD></TR>
    </TABLE>
  >]

  C [label=<
    <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
      <TR><TD><FONT POINT-SIZE='16'><B>3. Design stratified GSV sample</B></FONT></TD></TR>
      <TR><TD>Stratify tracts by density x centrality (3x3);<BR/>sample 6 tracts per stratum;<BR/>length-weighted ADD / REMOVE / NONCYC segments</TD></TR>
    </TABLE>
  >]

  D [label=<
    <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
      <TR><TD><FONT POINT-SIZE='16'><B>4. Inspect and code GSV</B></FONT></TD></TR>
      <TR><TD>Anchor years 2015 and 2023 (+/-1 year);<BR/>code 1 / 0 / NA at sampled points;<BR/>compare GSV patterns with OSM change</TD></TR>
    </TABLE>
  >]

  E [label=<
    <TABLE BORDER='0' CELLBORDER='0' CELLPADDING='4'>
      <TR><TD><FONT POINT-SIZE='16'><B>5. Evaluate OSM performance</B></FONT></TD></TR>
      <TR><TD>Derive TP / FP / FN;<BR/>compute precision, recall, F1<BR/>with 95 percent confidence intervals</TD></TR>
    </TABLE>
  >]

  det -> A [style=invis, weight=20]
  A -> B
  B -> val [style=invis, weight=20]
  val -> C [style=invis, weight=20]
  C -> D
  D -> E
}
")

dir.create("figs", recursive = TRUE, showWarnings = FALSE)

svg_txt <- export_svg(dot)
rsvg_svg(charToRaw(svg_txt), "figs/flowchart.svg")
rsvg_png(charToRaw(svg_txt), "figs/flowchart.png", width = 1400, height = 2200)
