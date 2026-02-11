/*
  Questo file gestisce la conversione:
  - da forme (RShape) in "spazio schermo" -> a forme in "spazio carta" (mm)
  - da forme -> a segmenti Linea (start/end) che poi diventano movimenti nel G-code

  In pratica qui avviene la trasformazione fondamentale:
  1) `ridimPaper()` applica scala (`factor`) e offset (xOffset/yOffset) alle shape
  2) `creaLista()` discretizza le shape in segmenti (Linee)
  3) `orderList()` raggruppa per colore, rimuove duplicati e spezza i segmenti troppo lunghi
  4) `orderBrigh()` riordina i gruppi colore per "brightness" (luminosita')
*/

// Ridimensiona (scala + trasla) tutte le shape in `formaList` nello spazio carta (mm)
void ridimPaper() {
  //orderList();
  //calcola il minimo e il massimo delle figure ridimensionate
  float xMin=100000.0;
  float yMin=10000.0;
  float xMax=0.0;
  float yMax=0.0;
  // per ogni shape calcola il fattore di scala e la traslazione
  //inverti l'asse x
  for (int i=0; i<formaList.size(); i++) {
    RShape s=formaList.get(i).sh;
    int    iCol=formaList.get(i).ic;
    int    typeC=formaList.get(i).type;
    // `factor` = mm / unita' schermo: porta la shape in millimetri
    s.scale(factor);
    // Offset su carta: permette di lasciare margini e posizionare la stampa sul foglio reale
    s.translate(xOffset, yOffset);

    paperFormList.add(new Forma(s, iCol, typeC));
    if (s.getX() < xMin)
      xMin=s.getX();
    if (s.getY() < yMin)
      yMin=s.getY();
    if ((s.getX()+s.getWidth()) > xMax)
      xMax=s.getX()+s.getWidth();
    if ((s.getY()+s.getHeight()) > yMax)
      yMax=s.getY()+s.getHeight();
  }
  println("Xmin:"+xMin+"  Ymin:"+yMin);
  println("Xmax:"+xMax+"  Ymax:"+yMax);
  noFill();
  stroke(0);
  xxMax=xMax;
  // rect(xOffset, yOffset, xDim, yDim);
}

////////////////////////////////////////////////////////////////////////////////////////////
// Crea `lineaList` trasformando ogni contorno/polilinea in segmenti consecutivi
// Nota: qui non esiste ancora alcuna logica di "pen-up" o percorsi ottimizzati: e' solo geometria.
void creaLista() {
  RCommand.setSegmentator(RCommand.ADAPTATIVE);
  for (int i=0; i<paperFormList.size(); i++) {
    // turn the RShape into an RPolygon
    RPolygon sPolygon = paperFormList.get(i).sh.toPolygon(); //prendi solo il contorno fatto di punti
    if (sPolygon.contours != null) {
      for (int k=0; k<sPolygon.contours.length; k++) {
        RPoint startS=sPolygon.contours[k].points[0]; //prendi il primo punto della shape e consideralo il primo vertice della prima riga
        RPoint endS=sPolygon.contours[k].points[0];
        //if (sPolygon.contours[0].points.length == 3) { //se uguale a 3 è una semplice linea
        //  endS=sPolygon.contours[0].points[1]; //metti alla fine il secondo punto del contorno
        //  lineaList.add(new Linea(startS, endS, paperFormList.get(i).ic, paperFormList.get(i).type)); //aggiungi un record alla lista di linee
        //} else  //la forma è complessa e ci sono molti punti
        //{
        // Ogni coppia di punti consecutivi diventa una Linea
        for (int j = 1; j < sPolygon.contours[k].points.length; j++) {
          endS = sPolygon.contours[k].points[j];   //prendi il finale della prossima riga
          lineaList.add(new Linea(startS, endS, paperFormList.get(i).ic, paperFormList.get(i).type));
          startS=endS; //la fine della precedente riga è l'inizio della nuova riga
        }
        
        // Chiudi il percorso solo se è un contorno (type 0)
        // Le linee di hatching (type 1) sono percorsi aperti e non devono essere chiuse (altrimenti si crea una linea doppia di ritorno)
        if (paperFormList.get(i).type == 0) {
          lineaList.add(new Linea(endS, sPolygon.contours[k].points[0], paperFormList.get(i).ic, paperFormList.get(i).type)); //chiudi dall'ultimo punto della shape al primo
        }
        // }
      }
    }
  }

  // Rimuove micro-segmenti:
  // durante la polygonization possono comparire segmenti quasi nulli (artefatti o punti ripetuti).
  // Su un plotter questi creano movimenti inutili e possono peggiorare la fluidita'.
  int removedMicro = 0;
  float minSegmentLength = 0.2;
  for (int i = lineaList.size() - 1; i >= 0; i--) {
    Linea curr = lineaList.get(i);
    if (dist(curr.start, curr.end) < minSegmentLength) {
      lineaList.remove(i);
      removedMicro++;
    }
  }
  println("Removed " + removedMicro + " micro-segments (< " + minSegmentLength + ")");

  println("Before remove duplicate:"+lineaList.size());

  /*
  //////////rimuovi le linee duplicate
   
   for (int i=1; i<lineaList.size(); i++) {
   Linea curr=lineaList.get(i);
   if (dist(curr.start, curr.end) < 0.1)
   lineaList.remove(i--);
   }
   for (int i=0; i<lineaList.size(); i++) {
   Linea curr=lineaList.get(i);
   for (int j=i+1; j<lineaList.size(); j++) {
   Linea prev=lineaList.get(j);
   boolean confronto=((prev.start.x==curr.start.x) && (prev.start.y == curr.start.y) && (prev.end.x == curr.end.x) && (prev.end.y == curr.end.y) && (prev.ic==curr.ic) && (prev.type==curr.type));
   if (confronto) {
   lineaList.remove(j--);
   }
   }
   }
   println("After remove duplicate:"+lineaList.size());
   */
}
//////////////////////////////////////////////////////////////////////////////////////
// Raggruppa `lineaList` per colore (ic), poi:
// - elimina duplicati (anche invertiti)
// - spezza segmenti troppo lunghi (maxDist) per rispettare limiti di "pittura continua"
//
// Nota: la rimozione duplicati e' efficace soprattutto per contorni e per alcuni hatch mode.
void  orderList() {
  ArrayList<Linea> ordLineaList = new ArrayList<Linea>();
  Linea ordLinea=lineaList.get(0);
  lineaList.remove(0);
  ordLineaList.add(ordLinea);
  int iColor=ordLinea.ic;
  while (lineaList.size()>0) {
    //  boolean trovato=false;
    int indElem=0;
    //   while (!trovato && indElem < lineaList.size()) {
    // Sposta in `ordLineaList` tutte le linee che condividono il colore corrente iColor.
    // Quando terminano, passa al prossimo colore (primo elemento rimasto).
    while (indElem < lineaList.size()) {
      ordLinea = lineaList.get(indElem);
      if (iColor == ordLinea.ic) {
        lineaList.remove(indElem);
        ordLineaList.add(ordLinea);
      } else {
        indElem++;
      }
    }
    if ((indElem) >= lineaList.size()) {
      if (lineaList.size() >0) {
        ordLinea = lineaList.get(0);
        lineaList.remove(0);
        ordLineaList.add(ordLinea);
        iColor=ordLinea.ic;
      }
    }
  }
  // Rimozione "grezza" dei segmenti quasi nulli (seconda difesa oltre a creaLista()).
  for (int i=1; i<ordLineaList.size(); i++) {
    Linea curr=ordLineaList.get(i);
    if (dist(curr.start, curr.end) < 0.2)
      ordLineaList.remove(i--);
  }

  for (int i=0; i<ordLineaList.size(); i++) {
    Linea curr = ordLineaList.get(i);
    color currColor = curr.ic;

    for (int j=i+1; j<ordLineaList.size(); j++) {
      Linea prev = ordLineaList.get(j);

      if (currColor != prev.ic) {
        // Poiche' la lista e' raggruppata per colore, quando cambia colore possiamo fermarci.
        j = ordLineaList.size();
        continue;
      }

      // Controllo linee duplicate esatte
      float tolerance = 0.1;
      boolean confrontoEsatto = (dist(prev.start, curr.start) < tolerance &&
                                 dist(prev.end, curr.end) < tolerance &&
                                 prev.ic == curr.ic);

      // Controllo linee sovrapposte inverse
      boolean confrontoInverso = (dist(prev.start, curr.end) < tolerance &&
                                  dist(prev.end, curr.start) < tolerance &&
                                  prev.ic == curr.ic);

      if (confrontoEsatto || confrontoInverso) {
        ordLineaList.remove(j--);
      }
    }
  }

  println("After remove duplicate:" + ordLineaList.size());
  //copy the list
  lineaList.clear();
  lineaList.addAll(ordLineaList);

  //////// calcola la lunghezza totale della lista per confronto con le spezzate
  float lungLista=0;
  for (int i=0; i<lineaList.size(); i++) {
    Linea t=lineaList.get(i);
    lungLista=lungLista+dist(t.start, t.end);
  }
  //  println("Lunghezza totale linee lista:"+lungLista);

  // Spezza le linee in pezzi piu' piccoli se maggiori di maxDist.
  // Motivazione: riduce colature/accumuli e permette cicli di "pulizia pennello" piu' frequenti.
  ordLineaList.clear();
  for (int i=0; i<lineaList.size(); i++) {
    Linea t=lineaList.get(i);
    float lungLinea=dist(t.start, t.end);
    if (lungLinea > maxDist) { //verifica se la linea è maggiore della max linea da dipingere
      float numPezzi=int(lungLinea/maxDist); //numero di pezzi in cui spezzare
      float restoLinea=lungLinea; //resto della linea che rimane da spezzare
      RPoint s=t.start;
      RPoint e=t.end;
      RCommand cLine;
      for (int j=0; j<int(numPezzi)+1; j++) {
        cLine = new RCommand(s.x, s.y, e.x, e.y);  //crea una linea con il pezzo rimanenente
        float rappLung=maxDist/restoLinea; // //prendi il punto sulla linea che corrisponde alla fine della maxDist
        RPoint onLine;
        if (rappLung>1)
          onLine=e;
        else
          onLine = cLine.getPoint(rappLung); //prendi il punto sulla linea che corrisponde alla fine della maxDist
        ordLineaList.add(new Linea(s, onLine, t.ic, t.type)); //aggiungi una linea alla lista fino a distMax
        s=onLine; //nuovo inizio della linea
        restoLinea=restoLinea-maxDist;
      }
    } else {
      ordLineaList.add(t);
    }
  }
  //copy the list
  lineaList.clear();
  lineaList.addAll(ordLineaList);
  //////// calcola la lunghezza totale della lista per confronto con le spezzate
  lungLista=0;
  for (int i=0; i<lineaList.size(); i++) {
    Linea t=lineaList.get(i);
    lungLista=lungLista+dist(t.start, t.end);
  }
  // println("Lunghezza totale linee lista after:"+lineaList.size());
  // println("Lunghezza totale linee lista after:"+lungLista);
}




//////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
void  orderBrigh() {
  // crea un vettore con la lista dei colori ordinati per brightness
  int totColori=palette.length;
  for (int i = 0; i < totColori; i++) {
    brighCol.add(new cBrigh(palette[i], i));
  }

  //for(int i = 0; i < totColori; i++)
  //  println(brighCol.get(i).indice+"  "+ hex(brighCol.get(i).colore));

  // Ordina i colori per "energia RGB" (approssimazione della luminosita'):
  //   a = r^2 + g^2 + b^2
  // Ordinamento decrescente: dal piu' "chiaro" (energia alta) al piu' "scuro".
  //
  // Nota: e' un bubble sort perche' la palette e' piccola e questo e' semplice da mantenere.
  for (int i = 0; i < totColori; i++) {
    boolean flag = false;
    for (int j = 0; j < totColori-1; j++) {
      //Se l' elemento j è minore del successivo allora
      //scambiamo i valori
      float a=red(brighCol.get(j).colore)*red(brighCol.get(j).colore)+ green(brighCol.get(j).colore)*green(brighCol.get(j).colore)+blue(brighCol.get(j).colore)*blue(brighCol.get(j).colore);
      float b=red(brighCol.get(j+1).colore)*red(brighCol.get(j+1).colore)+ green(brighCol.get(j+1).colore)*green(brighCol.get(j+1).colore)+blue(brighCol.get(j+1).colore)*blue(brighCol.get(j+1).colore);
      //    if(brightness(brighCol.get(j).colore)< (brightness(brighCol.get(j+1).colore))) {
      if (a < b) {
        cBrigh k =  brighCol.get(j);
        brighCol.set(j, brighCol.get(j+1));
        brighCol.set(j+1, k);
        flag=true; //Lo setto a true per indicare che é avvenuto uno scambio
      }
    }
    if (!flag) break; //Se flag=false allora vuol dire che nell' ultima iterazione
    //non ci sono stati scambi, quindi il metodo può terminare
    //poiché l' array risulta ordinato
  }

  for (int i = 0; i < totColori; i++)
    print("Colore "+i+": "+ hex(brighCol.get(i).colore)+" - ");
  println("");

  // Applica il nuovo ordine ai gruppi nella `lineaList`.
  // La logica:
  // - copia lineaList in una lista temporanea
  // - svuota lineaList
  // - per ogni colore ordinato, sposta tutte le linee che lo usano
  ArrayList<Linea> lineaBrigh = new ArrayList<Linea>();
  lineaBrigh.clear();
  lineaBrigh.addAll(lineaList);
  //azzera lineaList
  lineaList.clear();
  for (int i=0; i<totColori; i++) {
    //fai un ciclo e riempi la lista con le righe di brightness ordinate
    for (int j=0; j<lineaBrigh.size(); j++) {
      Linea curr=lineaBrigh.get(j);
      if (curr.ic==brighCol.get(i).indice) {  //cerca la linea del colore corretto
        curr.ic=i;
        lineaList.add(curr);
        lineaBrigh.remove(j--);
      }
    }
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Scrivi linee nel file
// scrivi in un file tutte le linee da dipingere
void scriviLineeFile() {
  for (int i=1; i<lineaList.size(); i++) {
    Linea curr=lineaList.get(i);
    String outLinee="Start:"+nf(curr.start.x, 0, 2)+" "+nf(curr.start.y, 0, 2)+"  End:"+nf(curr.end.x, 0, 2)+" "+nf(curr.end.y, 0, 2)+"  ic:"+curr.ic+"  type:"+curr.type+" lenght:"+nf(dist(curr.start, curr.end), 0, 2);
    linee.println(outLinee);
  }
}

float dist(RPoint start, RPoint end) {
  return sqrt((end.x-start.x)*(end.x-start.x)+(end.y-start.y)*(end.y-start.y));
}


float distV(PVector start, PVector end) {
  return sqrt((end.x-start.x)*(end.x-start.x)+(end.y-start.y)*(end.y-start.y));
}
