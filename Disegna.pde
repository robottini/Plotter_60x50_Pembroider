//////////////////////////////////////////////////////////////
//disegna le forme su schermo
void disegna() {

  for (int i=0; i<formaList.size(); i++) {
    noFill();
    strokeWeight(sovr);
    stroke(brighCol.get(i).colore);
    formaList.get(i).sh.draw();
  }
}

////////////////////////////////////////////////////////////////
// disegna le forme simulando le dimensioni della carta
void disegnaPaper() {
  for (int i=0; i<paperFormList.size(); i++) {
    noFill();
    strokeWeight(1);
    stroke(brighCol.get(i).colore);
    paperFormList.get(i).sh.draw();
  }
}

/////////////////////////////////////////////////////////////////
// disegna le linee scalando alle dimensioni dello schermo
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
  
  // Disegna tutti i gruppi di colori fino all'indice corrente
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
