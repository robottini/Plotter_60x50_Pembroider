/////////////////////////////////// //<>// //<>//

// variabili locali
int[] colorTable_GCode;
boolean is_pen_down;
float  max_gcode_x=0;
float  max_gcode_y=0;
float  min_gcode_x=10000;
float  min_gcode_y=10000;
float  min_line_x=10000;
float  min_line_y=10000;
float  max_line_x=0;
float  max_line_y=0;
int    Glines=0;
float  xCol, yCol, zCol;
boolean zFront=false;


///////////////////////////////////////////////////////////////////////////
void creaGCODE() {
  //Local variables
  int currCol=-1; //<>//
  float currDist=0;
  Linea currLinea;
  int typeLine=0;

  /// homing
  String buf = "$X"; 
  OUTPUT.println(buf); 
  Glines++;
  if (endStop){
    buf="$HZ";
    OUTPUT.println(buf); 
    Glines++;
    buf="$HY";
    OUTPUT.println(buf); 
    Glines++;
    buf="$HX";
    OUTPUT.println(buf); 
    Glines++; 
  }
  for (int i=0; i<lineaList.size(); i++) {
    currLinea=lineaList.get(i);
    typeLine=currLinea.type;

    // controlla colore. Se bianco vai alla prossima linea, se diverso dal precedente prendi il nuovo colore
    if (brighCol.get(currLinea.ic).colore == colHide)
      continue;
    if (currLinea.ic != currCol) {
      clean();
      takeColor(currLinea.ic);
      currCol=currLinea.ic;
      currDist=0;
    }

    // Controlla lunghezza linea totale. Se maggiore maxDist spezza la linea
    PVector in=new PVector(currLinea.start.x, currLinea.start.y);
    PVector fin = new PVector(currLinea.end.x, currLinea.end.y);
    float dimLinea=dist(currLinea.start, currLinea.end);
    float totDist=currDist + dimLinea; //lunghezza totale della linea
    buf = ";Tot Dist:"+ nf(totDist, 0, 1);
    OUTPUT.println(buf);

    if (totDist >= maxDist) { //se supera la lunghezza totale verifica quanti pezzi ci vogliono
      float manca=maxDist-currDist; //verifica quanto manca alla fine della linea corrente
      RCommand cLine = new RCommand(in.x, in.y, fin.x, fin.y);
      float rappLung=manca/dimLinea; //rapporto tra il pezzo di linea e tutta la linea per trovare il punto di rottura della linea
      RPoint onLine1 = cLine.getPoint(rappLung); //prendi il punto sulla linea che corrisponde alla fine della maxDist
      PVector onLine=new PVector(onLine1.x, onLine1.y);
      buf = ";Break the line:"+nf(dimLinea, 0, 1)+" disTot:"+nf(totDist, 0, 1) + " First Segment:"+nf(manca, 0, 1) + " Second segment:"+nf(dimLinea - manca, 0, 1);
      OUTPUT.println(buf);
      paint(in, onLine, typeLine);  //dipingi la linea che manca alla fine di maxDist7
      verGCode(in, onLine);
      float onLineX=onLine.x;
      float onLineY=onLine.y;
      currDist=0; //azzera la distanza della linea totale
      takeColor(currCol); // prendi il colore
      in.x=onLineX;
      in.y=onLineY;
    }
    //// paint the segment
    currDist=currDist+distV(in, fin);
    paint(in, fin, typeLine); //dipingi la linea
    verGCode(in, fin);
  }
}

///////////////////////////////// 
void paint(PVector s, PVector e, int typeLine) {
  if (!zFront)
    moveFront();    

  if (distV(pos, s) > distMinLines) {
    if (is_pen_down)
      pen_up();
    move_fast(s);
    pen_down();
    move_abs(e, typeLine);
    pos=e;
  } else {      
      buf = ";Near Line: "+nf(distV(pos, s), 0, 1) +" x1:"+ nf(pos.x, 0, 1) +" y1:"+ nf(pos.y, 0, 1) +" x2:"+ nf(s.x, 0, 1) +" y2:"+ nf(s.y, 0, 1);
      OUTPUT.println(buf);
      if (!is_pen_down)
        pen_down();
      if (distV(pos, s) > 0)
        move_abs(s, typeLine);
      move_abs(e, typeLine);
      pos=e;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////
void pen_up() {  //servo up
  String buf = "G1 Z" + absZUp +" F"+ speedFast; 
  OUTPUT.println(buf); 
  Glines++;
  is_pen_down=false;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////
void pen_down() { //servo down
  String buf = "G1 Z" + absZDown +" F"+ speedFast; 
  OUTPUT.println(buf);
  Glines++;
  is_pen_down=true;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////
void pen_color_up() { //servo down
  String buf = "G1 Z" + colZup +" F"+ speedFast; 
  OUTPUT.println(buf);
  Glines++;
  is_pen_down=false;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////
void pen_color_down() { //servo down
  String buf = "G1 Z" + colZDown +" F"+ speedFast; 
  OUTPUT.println(buf); 
  Glines++;
  is_pen_down=true;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////
void pen_water_down() { //servo down
  String buf = "G1 Z" + watZdown +" F"+ speedFast; 
  OUTPUT.println(buf); 
  Glines++;
  is_pen_down=true;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////
void move_abs(PVector p, int type) { //move slow for painting

  String buf;
  if (type == 0)
    buf = "G1 X" + nf(p.x, 0, 2) + " Y" + nf(p.y, 0, 2) +" F"+ speedContour; 
  else 
  buf = "G1 X" + nf(p.x, 0, 2) + " Y" + nf(p.y, 0, 2) +" F"+ speedAbs;
  buf=buf+" ;move_abs";
  OUTPUT.println(buf);  
  Glines++;
  pos=p;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////
void move_color_slow(PVector p) { //move slow for painting
  String buf;
  buf = "G1 X" + nf(p.x, 0, 2) +" F"+ speedAbs;
  buf=buf+" ;move_color_slow";
  OUTPUT.println(buf);  
  Glines++;
  pos=p;
}



///////////////////////////////////////////////////////////////////////////////////////////////////////
void move_fast(PVector p) { //move fast the brush //<>// //<>//
  String buf = "G0 X" + nf(p.x, 0, 2) + " Y" + nf(p.y, 0, 2);  //<--- F is the speed of the arm. Decrease it if is too fast
  buf=buf+" ;move_fast";
  OUTPUT.println(buf);  
  Glines++;
  pos=p;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////
void move_color_fast(float x, float y) { //go to color coordinate fast
  if (zFront){
    String buf = "G0 A" + nf(abszBack, 0, 2) +" X" + nf(x, 0, 2);  //<--- F is the speed of the arm. Decrease it if is too fast
    zFront=false;
    buf=buf+" ;goBack Brush";
    OUTPUT.println(buf);  
    Glines++;
  }
  else {    
  String buf = "G0 X" + nf(x, 0, 2);  //<--- F is the speed of the arm. Decrease it if is too fast
  buf=buf+" ;move_color_fast";
  OUTPUT.println(buf);  
  Glines++;
  }
  pos.x=x;
  pos.y=y;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////
void move_water_fast(PVector p) { //go to color coordinate fast
  if (zFront)
    moveBack(abszBack);
  String buf = "G1 X" + nf(p.x, 0, 2) +" A" + nf(p.y, 0, 2) +" F"+speedFast;  //<--- F is the speed of the arm. Decrease it if is too fast
  buf=buf+" ;move_water_fast";
  OUTPUT.println(buf);  
  Glines++;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////
void moveFront() {
  String buf = "G1 A" + nf(abszFront, 0, 2) +" F"+speedFast;  //<--- F is the speed of the arm. Decrease it if is too fast
  zFront=true;
  buf=buf+" ;goFront Brush";
  OUTPUT.println(buf);  
  Glines++;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
void moveBack(float abszBackPass) { //<>// //<>//
  String buf = "G1 A" + nf(abszBackPass, 0, 2) +" F"+speedFast;  //<--- F is the speed of the arm. Decrease it if is too fast
  zFront=false;
  buf=buf+" ;goBack Brush";
  OUTPUT.println(buf);  
  Glines++;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
void takeColor(int ic) {
  OUTPUT.println(";take color: "+ic);
  setCoordColor(ic);
  brushColor(xCol, yCol, zCol, ic);
  pos.x=xCol;
  pos.y=yCol;
  is_pen_down=false;
}  

 //<>// //<>//
//////////////////////////////////////////////////////
void setCoordColor(int index) {
  xCol=ColorCoord[index][0]; 
  yCol=ColorCoord[index][1];
  zCol=ColorCoord[index][2];
} 

//////////////////////////////////////////////////////
void brushColor(float xCol, float yCol, float zCol, int n) {
  if (is_pen_down)
    pen_color_up();
  move_color_fast(xCol, yCol);
  pen_color_down();
  PVector a=new PVector(xCol+random(-8,8), yCol);
  PVector b=new PVector(xCol+random(-8,8), yCol);
  PVector c=new PVector(xCol+random(-8,8), yCol);
  moveBack(abszBack+random(0,8));
  move_color_fast(a.x, a.y);
  moveBack(abszBack+random(0,8));
  move_color_fast(b.x,b.y);
  moveBack(abszBack+random(0,8));
  move_color_fast(c.x,c.y);
  moveBack(abszBack);
  pen_color_up();
  //move_fast(xOffset, yCol);
}


//////////////////////////////////////////////////////////////////////////////////////////////////////
//// clean the brush
void clean() {
  OUTPUT.println(";Clean brush");
  PVector a=new PVector(x_vaschetta+random(0,8), random(0,4));
  PVector b=new PVector(x_vaschetta-random(0,8), random(0,4));
  pen_color_up();
  move_color_fast(x_vaschetta, y_vaschetta);
  pen_water_down();
  for (int i=0; i<30; i++) {
    a=new PVector(x_vaschetta+random(0,10), random(0,4));
    b=new PVector(x_vaschetta-random(0,10), random(0,4));
    move_water_fast(a);
    move_water_fast(b);
  }
  a=new PVector(x_vaschetta+random(0,8), 0.0);
  move_water_fast(a);
  pen_color_up();
  pos.x=x_vaschetta;
  pos.y=y_vaschetta;
  is_pen_down=false;
  //move_color_fast(x_spugnetta, radiy-3); //spugna per asciugare
}



////////////////////////////////////////////////////////////////////////////////////////////
//two rows of 4 colors
//  O O    5 1
//  O O    6 2
//  O O    7 3
//  O O    8 4
//  O (water)

float[][] ColorCoord = {
  {
    radix, radiy, radiz //1st color
  }
  , {
    radix+add_x, radiy+add_y, radiz //2nd color
  }
  , {
    radix+2*add_x, radiy+2*add_y, radiz //3rd color
  }
  , {
    radix+3*add_x, radiy+3*add_y, radiz //4th color
  }
  , {
    radix+4*add_x, radiy+4*add_y, radiz //5th color
  }
  , {
    radix+5*add_x, radiy+5*add_y, radiz //6th color
  }
  , {
    radix+6*add_x, radiy+6*add_y, radiz //7th color
  }
  , {
    radix+7*add_x, radiy+7*add_y, radiz //8th color
  }
  , {
    radix+8*add_x, radiy+8*add_y, radiz //8th color
  }
  , {
    radix+9*add_x, radiy+9*add_y, radiz //8th color
  }
  , {
    radix+10*add_x, radiy+10*add_y, radiz //8th color
  }
  , {
    radix+11*add_x, radiy+11*add_y, radiz //8th color
  }
  , {
    radix+12*add_x, radiy+12*add_y, radiz //8th color
  }
};


////////////////////////////////////////////
void verGCode(PVector s, PVector e) {
  if (s.x < min_gcode_x)
    min_gcode_x=s.x;
  if (s.y < min_gcode_y)
    min_gcode_y=s.y;
  if (e.x < min_gcode_x)
    min_gcode_x=e.x;
  if (e.y < min_gcode_y)
    min_gcode_y=e.y;

  if (s.x > max_gcode_x)
    max_gcode_x=s.x;
  if (s.y > max_gcode_y)
    max_gcode_y=s.y;
  if (e.x > max_gcode_x)
    max_gcode_x=e.x;
  if (e.y > max_gcode_y)
    max_gcode_y=e.y;
}
