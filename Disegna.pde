/*
  Questo file contiene le funzioni di disegno a schermo e la preview interattiva.

  **Due modalita' di rendering**
  - Rendering "diretto": disegna RShape nello spazio schermo (forme originali / hatch in SVG-space)
  - Rendering "paper": disegna gli stessi elementi come sarebbero su carta (mm), ma ri-scalati sullo schermo

  **Preview interattiva**
  - `buildPreviewSteps()` costruisce una sequenza lineare di "passi" (contorno + hatch)
  - `disegnaPreview()` disegna tutti i passi fino a `currentPreviewStep`
  - Per ogni linea di hatch, mostra un punto rosso (start) e verde (end) per verificare la direzione
*/

// Disegna tutte le shape (in spazio schermo) usando lo stroke corrente
void disegna() {

  for (int i=0; i<formaList.size(); i++) {
    noFill();
    strokeWeight(sovr);
    stroke(brighCol.get(i).colore);
    formaList.get(i).sh.draw();
  }
}

////////////////////////////////////////////////////////////////
// Disegna `paperFormList` (spazio carta, mm) senza re-scaling:
// utile per debug "in mm", ma in genere non coincide con la scala della finestra.
void disegnaPaper() {
  for (int i=0; i<paperFormList.size(); i++) {
    noFill();
    strokeWeight(1);
    stroke(brighCol.get(i).colore);
    paperFormList.get(i).sh.draw();
  }
}

/////////////////////////////////////////////////////////////////
// Disegna tutte le linee finali (`lineaList`) riportandole dalla carta (mm) allo schermo:
// - translate(-offset) per tornare all'origine dell'SVG
// - scale(1/factor) per invertire la conversione mm <-> unita' schermo
void disegnaTutto() {
  background(255);
   
  for (int i=0; i<lineaList.size(); i++) {
    noFill();
    strokeWeight(sovr);
    stroke(brighCol.get(lineaList.get(i).ic).colore);
    RPoint t1= lineaList.get(i).start;
    RPoint t2=lineaList.get(i).end;
    RShape lineaSh=new RShape();  //definisci una shape con la linea
    lineaSh.addMoveTo(t1.x, t1.y);
    lineaSh.addLineTo(t2.x, t2.y);
    lineaSh.translate(-xOffset, -yOffset); //ritorna all'origine dello schermo
    lineaSh.scale(1/factor); //scala alla dimensione schermo
    lineaSh.draw();
  }
}


/////////////////////////////////////////////////////////////////
void disegnaLinea() {
  background(255);  
 
  if (indiceInizio >= lineaList.size())disegnaTutto();
  
  // Disegna tutti i gruppi di colori fino a `indiceFine`.
  // La lista e' gia' raggruppata per colore, quindi possiamo fermarci a un cambio colore.
  int i = 0;
  while (i < indiceFine) {
    color coloreGruppo = brighCol.get(lineaList.get(i).ic).colore;
    
    // Disegna tutte le linee dello stesso colore
    while (i < lineaList.size() && brighCol.get(lineaList.get(i).ic).colore == coloreGruppo) {
      noFill();
      strokeWeight(sovr);
      stroke(coloreGruppo);
      
      RPoint t1 = lineaList.get(i).start;
      RPoint t2 = lineaList.get(i).end;
      RShape lineaSh = new RShape();
      lineaSh.addMoveTo(t1.x, t1.y);
      lineaSh.addLineTo(t2.x, t2.y);
      lineaSh.translate(-xOffset, -yOffset);
      lineaSh.scale(1/factor);
      lineaSh.draw();
      
      i++;
    }
  }
  disegnaBlocchetti();
}

/////////////////////////////////////////////////////////////////
// Cambia il colore di alcune linee per creare nuance
void mixColor() {
  // "Nuance": per alcune linee di fill (type==1) riassegna un colore a caso.
  // Serve a sperimentare variazioni cromatiche senza modificare l'SVG.
  for (int i=0; i<lineaList.size(); i++) {
    Linea currLinea=lineaList.get(i);
    int caso=int(random(0, 15));
    if (caso == 4 && currLinea.type==1) {
      currLinea.ic=int(random(0, palette.length));
      lineaList.set(i,currLinea);
    }
  }
}



//////////////////////////////////////////////////////////////////
void disegnaBlocchetti() {
  // Disegna la palette come rettangoli in basso con etichetta numerica.
  // Il colore del testo e' scelto in base alla brightness per essere leggibile.
  for (int i=0; i<palette.length; i++) {
    float dimSq=xScreen/palette.length;
    stroke(0);
    fill(brighCol.get(i).colore);
    rect(dimSq*i, yScreen, dimSq*(i+1), yScreen+50);
    
    // Calcola il colore contrastante
    color c = brighCol.get(i).colore;
    float brightness = brightness(c);
    color textColor = brightness > 128 ? color(0) : color(255);
    
    // Aggiungi il numero
    fill(textColor);
    textAlign(CENTER, CENTER);
    textSize(30);
    text(str(i+1), dimSq*i + dimSq/2, yScreen + 25);
  }
}

//////////////////////////////////////////////////////////////////
// PREVIEW INTERATTIVA
//////////////////////////////////////////////////////////////////

class PreviewStep {
  // Un singolo "passo" della preview:
  // - se type=0: contorno (shape chiusa)
  // - se type=1: hatch (linea/segmento), con start/end evidenziati
  RShape sh;
  int ic;
  int type; // 0=contour, 1=hatch
  int shapeIndex;
  RPoint start, end;
  
  PreviewStep(RShape sh, int ic, int type, int shapeIndex) {
    this.sh = sh;
    this.ic = ic;
    this.type = type;
    this.shapeIndex = shapeIndex;
    
    // Calcola start/end per i punti rosso/verde (solo per hatching)
    if (type == 1) {
       RPoint[] points = sh.getPoints();
       if (points != null && points.length >= 2) {
         this.start = points[0];
         this.end = points[points.length-1];
       }
    }
  }
}

ArrayList<PreviewStep> previewSteps = new ArrayList<PreviewStep>();
int currentPreviewStep = -1;

void buildPreviewSteps() {
  // Costruisce la sequenza di preview a partire da `paperFormList`.
  //
  // In `paperFormList` la pipeline principale aggiunge prima tante linee di hatch e poi il contorno:
  //   [Hatch, Hatch, ..., Contour] (per ogni shape originale)
  //
  // Per la preview, e' piu' leggibile mostrare:
  //   [Contour, Hatch, Hatch, ...]
  previewSteps.clear();
  
  // paperFormList contiene sequenze di: [Hatch, Hatch, ..., Contour] per ogni forma originale.
  // Vogliamo trasformarle in: [Contour, Hatch, Hatch, ...] per la preview.
  
  ArrayList<PreviewStep> hatchBuffer = new ArrayList<PreviewStep>();
  int currentShapeIndex = 0;
  
  for (int i = 0; i < paperFormList.size(); i++) {
    Forma f = paperFormList.get(i);
    
    if (f.type == 1) {
      // È una linea di hatching, bufferizzala
      hatchBuffer.add(new PreviewStep(f.sh, f.ic, f.type, currentShapeIndex));
    } else if (f.type == 0) {
      // È un contorno, chiude la forma corrente
      
      // 1. Aggiungi il contorno
      previewSteps.add(new PreviewStep(f.sh, f.ic, f.type, currentShapeIndex));
      
      // 2. Aggiungi tutte le linee di hatching accumulate
      for (PreviewStep h : hatchBuffer) {
        previewSteps.add(h);
      }
      
      // Resetta buffer e incrementa indice forma
      hatchBuffer.clear();
      currentShapeIndex++;
    }
  }
  
  // Se rimangono hatch orfani (non dovrebbe accadere se la logica è corretta), aggiungili
  for (PreviewStep h : hatchBuffer) {
    previewSteps.add(h);
  }
}

void drawPreviewStep(int stepIndex) {
  if (stepIndex < 0 || stepIndex >= previewSteps.size()) return;
  
  PreviewStep step = previewSteps.get(stepIndex);
  
  // Ignora stili interni della shape per forzare il nostro colore
  RG.ignoreStyles(true);
  
  noFill();
  // Compensiamo lo scale(1/factor) applicato alla shape:
  // lo strokeWeight viene moltiplicato per factor per avere uno spessore visivo coerente.
  strokeWeight(sovr * factor);
  
  // Usa il colore corretto dalla mappa brighCol
  if (step.ic >= 0 && step.ic < brighCol.size()) {
     stroke(brighCol.get(step.ic).colore);
  } else {
     stroke(0);
  }
  
  RShape toDraw = new RShape(step.sh);
  toDraw.translate(-xOffset, -yOffset);
  toDraw.scale(1/factor);
  toDraw.draw();
  
  // Disegna punti start/end per hatching
  if (step.type == 1 && step.start != null && step.end != null) {
    // Trasforma le coordinate dei punti
    float sX = (step.start.x - xOffset) / factor;
    float sY = (step.start.y - yOffset) / factor;
    float eX = (step.end.x - xOffset) / factor;
    float eY = (step.end.y - yOffset) / factor;
    
    noStroke();
    fill(255, 0, 0); // Rosso start
    ellipse(sX, sY, 5, 5);
    
    fill(0, 255, 0); // Verde end
    ellipse(eX, eY, 5, 5);
  }
  
  RG.ignoreStyles(false);
}

void disegnaPreview() {
  // Disegna tutti i passi fino a quello selezionato.
  // `currentPreviewStep` viene aggiornato da keyPressed() nello sketch principale.
  background(255); // Sfondo bianco come richiesto (era nero nel precedente tentativo fallito)
  
  // Disegna tutti gli step fino a quello corrente
  for (int i = 0; i <= currentPreviewStep; i++) {
    drawPreviewStep(i);
  }
  
  // Disegna sempre la palette in basso
  disegnaBlocchetti();
}
