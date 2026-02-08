 /**
 * Funzione per creare un effetto di hatching (tratteggio) su una forma
 * Utilizza la libreria Geomerative per manipolare forme vettoriali
 * 
 * @param shape - La forma RShape da riempire con l'hatching
 * @param ic - Indice del colore da utilizzare per le linee di hatching
 * @param distContour - Distanza delle linee di hatching dal bordo della forma
 */
void intersection(RShape shape, int ic, float distContour) {
    RPoint[] ps = null; // Variabile dichiarata ma non usata in questo snippet

  // Ottiene i punti che formano il rettangolo di delimitazione della forma
  RPoint[] sb = shape.getBoundsPoints();
  // sb[0] tipicamente è il punto in alto a sinistra (minX, minY)
  // sb[1] tipicamente è il punto in alto a destra (maxX, minY)
  // sb[2] tipicamente è il punto in basso a destra (maxX, maxY)
  // sb[3] tipicamente è il punto in basso a sinistra (minX, maxY)

  // Crea un rettangolo con le dimensioni massime e minime della forma
  // Nota: L'oggetto Rsb non è strettamente necessario per calcolare l'angolo
  // della diagonale se usiamo direttamente i punti sb[0] e sb[2],
  // ma lo manteniamo se dovesse servire per altre parti del codice non mostrate.
  RShape Rsb = RShape.createRectangle(sb[0].x, sb[0].y, sb[1].x - sb[0].x, sb[2].y - sb[1].y);

  // Determina l'angolo della diagonale del rettangolo di delimitazione.
  // Calcoliamo l'angolo tra l'asse x positivo e il vettore
  // che va dal punto in alto a sinistra (sb[0])
  // al punto in basso a destra (sb[2]).
  // La funzione atan2(dy, dx) restituisce l'angolo in radianti.
  // Utilizziamo degrees() per convertirlo in gradi.

  float dx = sb[2].x - sb[0].x; // Differenza in x (larghezza del rettangolo)
  float dy = sb[2].y - sb[0].y; // Differenza in y (altezza del rettangolo)

  // Calcola l'angolo in radianti
  float angleRadians = atan2(dy, dx);

  // Converte l'angolo in gradi
  float angle = degrees(angleRadians)+90*random(0,2);
  // Calcola la diagonale del rettangolo di delimitazione
  float diag = sqrt(pow(sb[1].x-sb[0].x, 2) + pow(sb[2].y-sb[1].y, 2));
  // Calcola il numero di linee in base alla dimensione della diagonale e allo step
  int num = 2 + int(diag/stepSVG);   //provarapp
  // Lunghezza delle linee di hatching
  int hatchLength = int(stepSVG * (num-1)); //provarapp
 
  // Parte dal centro del rettangolo di delimitazione
  RPoint sbCenter = Rsb.getCenter();
  
  // Crea le linee di hatching
  for (int i = 0; i < num; i++) {
    // Crea una linea orizzontale e la ruota rispetto al centro
    RShape iLine = RShape.createLine(
      sbCenter.x - hatchLength/2, 
      sbCenter.y - hatchLength/2 + i*stepSVG,  //provarapp 
      sbCenter.x + hatchLength/2, 
      sbCenter.y - hatchLength/2 + i*stepSVG   //provarapp
    );
    // Ruota la linea in base all'angolo calcolato
    iLine.rotate(radians(angle), sbCenter);
    
    // Trova le intersezioni tra la linea e la forma
    ps = shape.getIntersections(iLine);
    
    if (ps != null && ps.length > 0) {
      // Crea una lista di punti di intersezione e utilizza Collections.sort per un ordinamento efficiente
      ArrayList<RPoint> pointList = new ArrayList<RPoint>();
      for (RPoint p : ps) {
        pointList.add(new RPoint(p));
      }
      
      // Ordina i punti per coordinata x crescente usando un comparatore
      Collections.sort(pointList, new Comparator<RPoint>() {
        public int compare(RPoint p1, RPoint p2) {
          return Float.compare(p1.x, p2.x);
        }
      });
      
      // Processa le coppie di punti per creare segmenti di hatching
      for (int p = 0; p < pointList.size() - 1; p += 2) {
        if (p + 1 < pointList.size()) {
          // Calcola il punto medio tra due punti di intersezione
          RPoint p1 = pointList.get(p);
          RPoint p2 = pointList.get(p+1);
          RPoint medLinea = new RPoint((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
          
          // Verifica se il punto medio è all'interno della forma
          if (shape.contains(medLinea)) {
            // Crea una linea tra i due punti di intersezione
            RCommand cLine = new RCommand(p1.x, p1.y, p2.x, p2.y);
            float lenLine = cLine.getCurveLength();
            
            // Verifica se la linea è abbastanza lunga per essere visualizzata
            if (lenLine > stepSVG+1.0) {  // Controllo reintrodotto come richiesto  provarapp
              // Calcola la percentuale della linea da ritagliare per rispettare distContour
               float percSplit=distContour / lenLine;
              RShape hatchLine;
              
              if (percSplit < 1) {
                // Ritaglia la linea per mantenere la distanza dal bordo
                RCommand[] endLine = cLine.split(1.0 - percSplit);
                RCommand[] startLine = cLine.split(percSplit);
                RPoint start = startLine[1].startPoint;
                RPoint end = endLine[0].endPoint;
                hatchLine = RShape.createLine(start.x, start.y, end.x, end.y);
              } else {
                // La linea è troppo corta per essere ritagliata, usa i punti originali
                hatchLine = RShape.createLine(p1.x, p1.y, p2.x, p2.y);
              }
              
              // Aggiunge la linea di hatching alla lista delle forme
              formaList.add(new Forma(hatchLine, ic, 1));
            }
          }
        }
      }
    }
  }
}

/////////////////////////////////////////////////////////
// clasee di shape usata sia per lo schermo che per la lista su carta
class Forma {
  RShape sh;  //shape
  int   ic;   //indexColor
  int   type;  //type 0=contour, type 1=fill

  Forma(RShape sh, int ic, int type) {
    this.sh=sh;
    this.ic=ic;
    this.type=type;
  }
}

//////////////////////////////////////////////////////////////////
// classe con due punti che formano la linea che sarà poi dipinta
class Linea {
  RPoint start;  //line start point
  RPoint end;    //line end point
  int   ic;   //indexColor
  int   type;  //type 0=contour, type 1=fill

  Linea(RPoint start, RPoint end, int ic, int type) {
    this.start=start;
    this.end=end;
    this.ic=ic;
    this.type=type;
  }
}



//////////////////////////////////////////////////////////////////
// classe per ordinare i colori in base alla brightness
class cBrigh {
  color colore;  //line start point
  int   indice;    //line end point

  cBrigh(color colore, int indice) {
    this.colore=colore;
    this.indice=indice;
  }
}
