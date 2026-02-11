/*
  Questo file si occupa dell'estrazione delle primitive dall'SVG (Geomerative).

  `exVert` attraversa ricorsivamente l'albero di RShape:
  - se una shape ha children, visita ogni child e ne legge fillColor
  - se una shape e' "foglia" (nessun child), converte i path in un RShape composto da segmenti lineari
    e lo inserisce in `bezier` (lista delle forme da processare).

  Durante la visita costruisce anche:
  - `palette` (array color) e `colori` (IntList) con i colori incontrati
  - `ve` (ArrayList<Point>) con tutti i vertici, usato principalmente per debug/analisi
*/

void exVert(RShape s, color fil) {
RShape[] ch; // children
int n, i, j;
RPoint[][] pa;

n = s.countChildren();
if (n > 0) {
ch = s.children;
for (i = 0; i < n; i++) {
  // Ogni child puo' avere il suo stile (fillColor).
  // Questo valore viene propagato ricorsivamente fino alle foglie.
  fil = ch[i].getStyle().fillColor;
  if (!colori.hasValue(fil)) {
    if (!primoColore){
    colori.append(fil);
    palette=expand(palette,contaColSVG+1); //espandi la palette dei colori
    palette[contaColSVG++]=fil;
    }
    // Primo colore: molti SVG esportati hanno un primo path "nero" di servizio.
    // Questa logica evita di considerare il nero come "primo" in alcune condizioni.
    if (primoColore && fil != #000000)
      primoColore=false;
}
  exVert(ch[i], fil);
}
}
else { // no children -> work on vertex
// Caso foglia: converti i punti dei path in un RShape con segmenti lineari.
pa = s.getPointsInPaths();
n = pa.length;
RShape a=new RShape();
a.setFill(fil);
a.setStroke(fil);

if (!colori.hasValue(fil)) {
  if (!primoColore){
  colori.append(fil);
  palette[contaColSVG++]=fil;
  }
  if (primoColore && fil != #000000)
    primoColore=false;
}

for (i=0; i<n; i++) {
for (j=0; j<pa[i].length; j++) {
//ellipse(pa[i][j].x, pa[i][j].y, 2,2);
if (j==0){
  // Primo punto del path: moveTo (non disegna)
  a.addMoveTo(pa[i][j].x, pa[i][j].y);
  // z=-10 e z=0 sono convenzioni locali per distinguere l'inizio del path dagli altri punti
ve.add(new Point(pa[i][j].x, pa[i][j].y, -10.0));
}
else {
// Punti successivi: lineTo (segmento dal punto precedente)
a.addLineTo(pa[i][j].x, pa[i][j].y);
ve.add(new Point(pa[i][j].x, pa[i][j].y, 0.0)); }
}
}
bezier.add(a);
//println("#paths: " + pa.length);
}
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Class for a 3D point
//
class Point {
float x, y, z;
Point(float x, float y, float z) {
this.x = x;
this.y = y;
this.z = z;
}

void set(float x, float y, float z) {
this.x = x;
this.y = y;
this.z = z;
}
}
