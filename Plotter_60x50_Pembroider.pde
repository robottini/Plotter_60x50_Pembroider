// Viene creato il gcode a partire da una immagine SVG. L'immagine è di 1000x700 pixel 
// viene creata una classe contenente anche il colore e la tipologia di forma (0=contorno, 1=filling)
// ogni shape (contorno o fill) viene inserita nella lista
// viene creata una nuova lista normalizzata alle dimensioni del foglio 
// crea una lista di sole linee a partire dalle shape
// viene creato il GCode a partire dalla lista normalizzata

import geomerative.*;
import java.util.Locale;
import java.util.Date;  
import java.text.SimpleDateFormat; 
import java.util.Collections;
import java.util.Comparator;
// Aggiunti import per le classi del calcolatore di tempo
import java.util.*;
import java.util.regex.*;
import java.io.*;
import java.nio.file.*; // Potrebbe non essere strettamente necessario se si usa loadStrings

//Variabili del disegno
float step=1.2;
float stepDisplay; float stepSVG; //provarapp
boolean mixColors=false; //mescola i colori ogni tanto
boolean hatching=true; //ottieni i riempimenti a linee parallele
boolean endStop=false;
//boolean border=true; //ottieni i bordi dell'immagine

//Dimensioni del foglio
//A3 395 260 0 50
//A4 285 205 0 35
//A3 Yupo 395 255 0 55
//max DIM Y = 650mm
int xDim=410;   //dimensione x della carta utile per dipingere
int yDim=290; //dimensione y della carta utile per dipingere
int xOffset=5; //offset x su carta
int yOffset=50; //offset y su carta
float rapp_carta=float(xDim)/float(yDim);
int xScreen=0;
int yScreen=0; //dimensione y dello screen
float xxMax=0;
int dimScreenMax=1000;

float distHatch=2; //distanza tra inizio e fine del tratteggio e il bordo
color colHide=#E3E4E6; //colore da non fare - FFFFFF = Bianco puro


///  variabili importanti per GCODE
float maxDist=35.0; //max lenght line painted - paper coordinate
float distMinLines=2; //min distance between lines without up the pen

///coordinate per GCODE
float absZDown=68.0;  //value Z when down paining
float radix=41.0+10.0;    //x base coordinate for first color
float radiy=0.0;  //y base coordinate for first color
float radiz=0.0;   //z base coordinate for first color
float absZUp=absZDown-30.0;  // value Z when up
float colZup=absZDown-66.0;   // value Z when up taking color
float colZDown=absZDown-30.0;  // value Z when down taking color
float watZUp=colZup;   //value Z when up taking water
//float watZdown=10.0; //value Z when down taking water
float watZdown=absZDown-30.0; //value Z when down taking water
float abszFront=33.0; //value A when painting
float abszBack=0.1;   //vale A when taking color
float spongeZup=0.0;      //value Z when up going on the sponge
float spongeZDown=0;    //value Z when down on the spongef

float add_x=41.0;   //x step for every color
float add_y=0.0;   //y step for every color

//float x_vaschetta=radix+8.5*add_x;   //x water
//float y_vaschetta=radiy+8.5*add_y; //y water
float x_vaschetta=10.0;   //x water
float y_vaschetta=0.0; //y water
float x_spugnetta=radix+10.0*add_x; //x sponge
float y_spugnetta=radiy+10.0*add_y; //x sponge
boolean spugnetta=false; //if need to dry the brush on the sponge

// velocità 
float speedAbs=1500.0;  //value of speed when painting
float speedFast=10000.0; // value of speed when traveling
float speedContour=1500.0; //value of speed painting the contours

boolean WriteFileLine=true; //scrivi anche il file con le linee e i valori delle linee 
boolean contour_white=false;  //contorno bianco delle figure 
float shRed=0.8; //riduzione della shape per avere il bianco intorno - non usato
String nomeAlgo="SVG"; //prefisso con cui vengono salvati i file
float angle; //angolo delle linee - da definire se lo vuoi fisso
float sovr; // larghezza righe in pixel
//float sovr=2; // larghezza righe in pixel

//color[] palette = {#ffff00, #800000, #00ffff, #ff0000, #ffffff, #ff00ff, #0000ff, #800080};
int numColori=1; //numero dei colori iniziale. Viene poi aumentato leggendo il file SVG
color[] palette = new color[numColori];

ArrayList<Forma> formaList = new ArrayList<Forma>();
ArrayList<Forma> paperFormList = new ArrayList<Forma>();
ArrayList<Linea> lineaList = new ArrayList<Linea>();
ArrayList<cBrigh> brighCol = new ArrayList<cBrigh>(); 

float factor;
PVector pos = new PVector(0, 0);  
String buf="";
PrintWriter OUTPUT, linee; 
String outFile=null; // Reso globale per essere accessibile dalla funzione di stima
// Variabili globali
int indiceInizio = 0;    // Indice di inizio del gruppo corrente
int indiceFine = 0;      // Indice che tiene traccia di quanto avanti siamo arrivati

/////////////////////
// Variabili disegno corrente
String nomeFile="";
String imgPath, path, fileN, fileNoExt;
PrintWriter reordFile; 

RShape img;
ArrayList ve;
int nve = 1;
int colo;
ArrayList<RShape> LShape=new ArrayList<RShape>();
IntList colori=new IntList();
IntList colSVG=new IntList();
int contaColSVG=0;
int conta=0;
int contaShape=0;
boolean primoColore=true;
float screenScaleFactor=0;
long durata=0;

ArrayList<RShape> bezier = new ArrayList<RShape>();

// Variabili globali per la stima del tempo G-code (aggiunte da claude.txt)
RussolinoMachineParams machineParams;
RussolinoTimeEstimator estimator;


/////////////////////////
void settings() {
  
  if (rapp_carta >= 1) {
    xScreen=dimScreenMax; //dimensioni x dello screen
    yScreen=int(dimScreenMax/rapp_carta); //dimensione y dello screen
  } else {
    yScreen=dimScreenMax;
    xScreen=int(dimScreenMax*rapp_carta);
  }
  
  size(xScreen, yScreen+100);
  pixelDensity(1);
  Locale.setDefault(Locale.US);
}

//////////////////////////////////////////////////////////////////////////
void setup() {
  windowResize(xScreen, yScreen+100);
  RG.init(this);
  durata=millis();

  // Inizializza i parametri della macchina e lo stimatore del tempo
  machineParams = new RussolinoMachineParams();
  estimator = new RussolinoTimeEstimator(machineParams, this); // Passa 'this' per accedere a loadStrings()

  selectInput("Please select canvas picture:", "selectImage");
  while (img == null)  delay(100);
  background(255, 255, 255);
  
  println("*******************************************************************");
  int imageHeight=int(img.getHeight());
  int imageWidth=int(img.getWidth());
  println("Original SVG x size:"+imageWidth);
  println("Original SVG y size:"+imageHeight);

  float scaleImgX=0;
  float scaleImgY=0;
  if (rapp_carta >1) {
    scaleImgX = float(xScreen) / img.getWidth();
    img.scale(scaleImgX);
     if (img.getHeight() > yScreen) {
      scaleImgY = float(yScreen) / img.getHeight();
      img.scale(scaleImgY);
    }
  }
   else {
    scaleImgY = float(yScreen) / img.getWidth();
    img.scale(scaleImgY);
    if (img.getWidth() > xScreen) {
      scaleImgX = float(xScreen) / img.getWidth();
      img.scale(scaleImgX);
    }
   }
  println("Screen X :"+xScreen);
  println("Screen Y :"+yScreen);
  
  imageHeight=int(img.getHeight());
  imageWidth=int(img.getWidth());
  println("New SVG x size:"+imageWidth);
  println("New SVG y size:"+imageHeight);

  // Calculate aspect ratio of the image
  float imageAspectRatio = (float) imageWidth / imageHeight;
  println("Image Aspect Ratio: " + imageAspectRatio);

  // Determine which dimension (X or Y) of the image is the maximum
  boolean isXMax = imageWidth >= imageHeight;
  println("Is X dimension of the image maximum? " + isXMax);
  float maxSVG=isXMax ? imageWidth : imageHeight;   //provarapp
  println("Maximum Dimension SVG: "+ maxSVG);       //provarapp
  // Determine the maximum dimension based on the screen size
 
  float maxDimension = isXMax ? xScreen : yScreen;
  println("Maximum Dimension: " + maxDimension);
  
  float svgScaleFactor=maxSVG / (isXMax ? xDim : yDim);   //provarapp

  // Calculate scaling factor for mapping to screen dimensions
  screenScaleFactor = maxDimension / (isXMax ? imageWidth : imageHeight);
  println("Screen Scale Factor: " + screenScaleFactor);

  // Map the dimensions to screen size
  float printedScreenWidth = imageWidth * screenScaleFactor;
  float printedScreenHeight = imageHeight * screenScaleFactor;
  println("Printed Screen Width: " + printedScreenWidth);
  println("Printed Screen Height: " + printedScreenHeight);

  // Calculate scaling factor for mapping to paper dimensions
  float paperWidthScaleFactor = float(xDim) / float(imageWidth);
  float paperHeightScaleFactor = float(yDim) / float(imageHeight);
  
  println("Paper Width Scale Factor: " + paperWidthScaleFactor);
  println("Paper Height Scale Factor: " + paperHeightScaleFactor);
  
  // Choose the smaller scale factor to ensure the image fits within both screen and paper
  float scaleFactor = min(screenScaleFactor, min(paperWidthScaleFactor, paperHeightScaleFactor));
  println("Chosen Scale Factor: " + scaleFactor);
  
  // Map the dimensions to paper size
  float printedPaperWidth = imageWidth * scaleFactor;
  float printedPaperHeight = imageHeight * scaleFactor;
  println("Printed Paper Width: " + printedPaperWidth);
  println("Printed Paper Height: " + printedPaperHeight);
 
  // Calculate reduction factor between screen dimensions and paper dimensions
  float reductionFactorWidth =  printedPaperWidth / printedScreenWidth;
  float reductionFactorHeight = printedPaperHeight / printedScreenHeight;
  println("Reduction Factor Width: " + reductionFactorWidth);
  println("Reduction Factor Height: " + reductionFactorHeight);

  //factor=reductionFactorWidth*screenScaleFactor;
  factor=scaleFactor;
  println("Redction factor paper vs screen:"+factor);

  stepSVG=step * svgScaleFactor;
  stepDisplay=step/factor;
  sovr=stepDisplay-0.5;
  print("Step paper:"+step); 
  print(" - Step display:"+stepDisplay);
  print(" - StepSVG:" + stepSVG);
  println(" - sovr:"+sovr);
    
 // yOffset=yOffset-int(printedPaperHeight);
 // xOffset=xOffset-int(printedPaperWidth);
  
  println("*******************************************************************");

 ///// ////////////////////////////////////////////////////////////////
 //***********************************************************************************************************
  // disegno corrente
  ve= new ArrayList();
  RG.setPolygonizer(RG.ADAPTATIVE);
  color fil=img.getStyle().fillColor;
  exVert(img, fil);
  println("tot punti da SVG: " + ve.size());
  println("tot Forme da SVG: " +bezier.size());
  print("Linee hatcging processate:");
  for (int p=0; p<bezier.size(); p++) {
    RShape curr=bezier.get(p);
    int colForm=curr.getStyle().fillColor;
    if (colForm == #FFFFFF) {
      bezier.remove(p);
      p--;
      continue;
    }
    int ic=-1;
    for (int i=0; i<palette.length; i++) {
      if (palette[i]==colForm) {
        ic=i;
        i=palette.length;
      }
    } 

    if (p%50 == 0) print(p+"...");
    if (hatching) {
      intersection(curr, ic, distHatch); //esegui hatch
    }
    
    RShape currResize=curr;
    RPoint originalCenter = curr.getCenter();
    RPoint[] sb = currResize.getBoundsPoints();
    RShape Rsb = RShape.createRectangle(sb[0].x, sb[0].y, sb[1].x-sb[0].x, sb[2].y-sb[1].y);
    boolean isRsbMax = Rsb.getWidth() >= Rsb.getHeight();
    float maxRsb= isRsbMax ? Rsb.getWidth(): Rsb.getHeight();   //provarapp
    float factorCurrResize=stepSVG/maxRsb;
    currResize.scale(1.0-factorCurrResize);
    RPoint newCenter = curr.getCenter();
    float dx = originalCenter.x - newCenter.x;
    float dy = originalCenter.y - newCenter.y;
  
  // Apply the translation to restore the center position
    currResize.translate(dx, dy);
    formaList.add(new Forma(currResize, ic, 0)); //aggiunge il contorno alle shape
    
    
  }
  println();
  println("Numero shape ottenute:"+formaList.size()); //scrivi il numero di poligoni
  println("Numero colori da SVG:"+palette.length);

  //disegna();  // traccia tutte le linee sullo schermo 
  ridimPaper(); // ridimensiona secondo le dimensioni della carta
  if (WriteFileLine)
    linee.println("Numero di shape:"+formaList.size());
  println("Numero di shape:"+formaList.size());
  println("*******************************************************************");
  creaLista();  // passa da shape a linee
  if (WriteFileLine)
    linee.println("Numero di linee:"+lineaList.size());
  orderList();  // metti tutti i colori insieme
  if (mixColors) 
    mixColor();    //cambia il colore di alcune linee
  orderBrigh(); // ordina le linee - brightness più alta prima
  background(255);
  disegnaTutto(); //disegna le linee
  creaGCODE();  //crea il gcode
  //aggiungi rettangolini con i colori
  disegnaBlocchetti();

  /*
  for (int j=0; j < palette.length; j++) {
   int g= palette[j];
   println("Colore "+j+" - "+hex(g));
   }
   */
  if (WriteFileLine) {
    linee.println("GCode Lines:"+Glines);
    linee.print("Min Gcode x:"+min_gcode_x);
    linee.println("  Max Gcode x:"+max_gcode_x);
    linee.print("Min Gcode y:"+min_gcode_y);
    linee.println("  Max Gcode y:"+max_gcode_y+"\n\n");
    scriviLineeFile(); // scrivi in un file tutte le linee da disegnare
  }
  
  pen_color_up();
  String buf = "G0 Z0";
  OUTPUT.println(buf);  
  Glines++;
  buf = "G1 X0 Y0 F6000";
  OUTPUT.println(buf);  
  Glines++;
  buf = "G0 A0";
  OUTPUT.println(buf);  
  Glines++;

  if (WriteFileLine) {
    linee.flush();
    linee.close();
  }

  OUTPUT.flush();
  OUTPUT.close();

  println("GCode Lines:"+Glines);
  print("Min Gcode x:"+min_gcode_x);
  println("  Max Gcode x:"+max_gcode_x);
  print("Min Gcode y:"+min_gcode_y);
  println("  Max Gcode y:"+max_gcode_y);

  saveFrame(path + "GCODE/" + fileNoExt + "-screen.png");
  println("Done saving.");
  println("Elaboration time (tenths): "+(millis()-durata)/100);
  
  
  // Chiama la funzione per calcolare e visualizzare il tempo di esecuzione del G-code
  calculateGCodeTime();


  println("End of elaboration");
}


void draw() {
}


////////////////////////////////////////////////
void selectImage(final File f) {
  if (f == null || f.isDirectory()) {
    println("Window was closed or you've hit cancel.\n");
    System.exit(0);
  }
  
  // Verifica se il file selezionato è un file SVG
  String fileName = f.getName().toLowerCase();
  if (!fileName.endsWith(".svg")) {
    println("Please select a SVG file (.svg extension)");
    selectInput("Please select a SVG file:", "selectImage");
    return;
  }
  
  imgPath = f.getPath();
  println("Img Path: "+imgPath);
  int indFile= imgPath.lastIndexOf("\\");
  path=imgPath.substring(0, indFile+1);
  fileN=imgPath.substring(indFile+1, imgPath.length() ); 
  println("Input Path: "+path);
  fileNoExt=fileN.substring(0, fileN.length()-4 );
  outFile=path+"GCODE\\"+fileNoExt+".GCODE"; // Assegna a outFile globale
  String lineeFile=path+"GCODE\\"+fileNoExt+".txt";
  OUTPUT = createWriter(outFile);
  if (WriteFileLine) {
    linee=createWriter(lineeFile);
    linee.println("Dimensioni foglio:"+xDim+"x"+yDim);
    linee.println("Offset:"+xOffset+"x"+yOffset+"\n");
  }
  println("output file:"+outFile);
  println("******************************************************");
  if ((img = RG.loadShape(imgPath)) == null) {
    println("is an invalid image file. Try again...\n");
    selectInput("Please select a SVG file:", "selectImage");
  }
}
////////////////////////////////////////////////////////////////////////
String timestamp() {
  // timestamp
  Date date = new Date();
  SimpleDateFormat sdf = new SimpleDateFormat("yyMMdd-HHmmss");
  return sdf.format(date);
}

//////////////////////////////////////////////////////////////////////
void mouseWheel(MouseEvent event) {
  if (indiceFine >= lineaList.size()) {
    indiceFine=lineaList.size()-1;
  }
  float e = event.getCount();
  
  if (e < 0) {  // Rotella in avanti
    // Trova la fine del gruppo colore corrente
    color coloreCorrente = brighCol.get(lineaList.get(indiceFine).ic).colore;
    while (indiceFine < lineaList.size() && 
           brighCol.get(lineaList.get(indiceFine).ic).colore == coloreCorrente) {
      indiceFine++;
    }
  } 
  else {  // Rotella all'indietro
    if (indiceFine > 0) {
      // Torna indietro all'inizio del gruppo colore precedente
      color coloreCorrente = brighCol.get(lineaList.get(indiceFine - 1).ic).colore;
      while (indiceFine > 0 && 
             brighCol.get(lineaList.get(indiceFine - 1).ic).colore == coloreCorrente) {
        indiceFine--;
      }
    }
  }
  
  disegnaLinea();
}
