void exVert(RShape s, color fil) {
RShape[] ch; // children
int n, i, j;
RPoint[][] pa;

n = s.countChildren();
if (n > 0) {
ch = s.children;
for (i = 0; i < n; i++) {
  fil = ch[i].getStyle().fillColor; // get opacity of path
  if (!colori.hasValue(fil)) {
    if (!primoColore){
    colori.append(fil);
    palette=expand(palette,contaColSVG+1); //espandi la palette dei colori
    palette[contaColSVG++]=fil;
    }
    if (primoColore && fil != #000000)
      primoColore=false;
}
  exVert(ch[i], fil);
}
}
else { // no children -> work on vertex
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
  a.addMoveTo(pa[i][j].x, pa[i][j].y);
ve.add(new Point(pa[i][j].x, pa[i][j].y, -10.0));
}
else {
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
