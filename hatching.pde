 /**
 * Funzione per creare un effetto di hatching (tratteggio) su una forma
 * Utilizza la libreria Geomerative per manipolare forme vettoriali
 * 
 * @param shape - La forma RShape da riempire con l'hatching
 * @param ic - Indice del colore da utilizzare per le linee di hatching
 * @param distContour - Distanza delle linee di hatching dal bordo della forma
 */
import processing.embroider.*;
PEmbroiderGraphics E;

void ensurePE() {
  if (E == null) {
    int w = width;
    int h = height;
    if (w <= 0) w = (xScreen > 0 ? xScreen : (dimScreenMax > 0 ? dimScreenMax : 1000));
    if (h <= 0) h = (yScreen > 0 ? (yScreen + 100) : (dimScreenMax > 0 ? dimScreenMax : 1000));
    if (w <= 0) w = 1;
    if (h <= 0) h = 1;
    E = new PEmbroiderGraphics(this, w, h);
    E.beginDraw();
    
    // --- CONFIGURAZIONE BASE PER PLOTTER ---
    // I plotter lavorano con linee (stroke), non con riempimenti (fill)
    E.noFill(); 
    E.stroke(0);        // Colore nero per il tratto
    E.strokeWeight(1);  // Spessore unitario
    
    // --- OTTIMIZZAZIONI SPECIFICHE ---
    // Disabilita il ricampionamento delle linee in piccoli punti (stitch).
    // I plotter preferiscono linee continue o segmenti lunghi definiti dalla geometria,
    // evitando di spezzare una linea retta in centinaia di piccoli movimenti.
    E.toggleResample(false); 
    applyPlotterSettingsSafe(E);
    
    // Nota: Per l'export finale, si consiglia di usare E.optimize() prima di salvare,
    // ma attenzione che può essere lento. Per i plotter, disabilitare jump stitches
    // e nodi è fondamentale (spesso gestito in fase di export o post-processing).
  }
}

void applyPlotterSettingsSafe(PEmbroiderGraphics e) {
  if (e == null) return;
  try {
    java.lang.reflect.Method m = e.getClass().getMethod("toggleConnectingLines", boolean.class);
    m.invoke(e, false);
  } catch (Exception ex) {
  }
  try {
    java.lang.reflect.Field f = e.getClass().getField("CONCENTRIC_ANTIALIGN");
    try {
      f.setFloat(null, 0.0f);
    } catch (Exception ex) {
      f.setFloat(e, 0.0f);
    }
  } catch (Exception ex) {
  }
}

RShape rshapeFromPELine(float x1, float y1, float x2, float y2) {
  return RShape.createLine(x1, y1, x2, y2);
}

PVector firstNonNullPVector(ArrayList<PVector> poly) {
  if (poly == null) return null;
  for (int i = 0; i < poly.size(); i++) {
    PVector p = poly.get(i);
    if (p != null) return p;
  }
  return null;
}

PVector lastNonNullPVector(ArrayList<PVector> poly) {
  if (poly == null) return null;
  for (int i = poly.size() - 1; i >= 0; i--) {
    PVector p = poly.get(i);
    if (p != null) return p;
  }
  return null;
}

RShape rshapeFromPolyline(ArrayList<PVector> poly, boolean reverse) {
  if (poly == null || poly.size() < 2) return null;
  RShape s = new RShape();
  if (!reverse) {
    PVector first = firstNonNullPVector(poly);
    if (first == null) return null;
    s.addMoveTo(first.x, first.y);
    for (int i = 1; i < poly.size(); i++) {
      PVector p = poly.get(i);
      if (p == null) continue;
      s.addLineTo(p.x, p.y);
    }
  } else {
    PVector first = lastNonNullPVector(poly);
    if (first == null) return null;
    s.addMoveTo(first.x, first.y);
    for (int i = poly.size() - 2; i >= 0; i--) {
      PVector p = poly.get(i);
      if (p == null) continue;
      s.addLineTo(p.x, p.y);
    }
  }
  return s;
}

void intersection(RShape shape, int ic, float distContour) {
  if (hatchAlgoKey != null && hatchAlgoKey.equals("PEMBROIDER")) {
    intersectionPEmbroider(shape, ic, distContour);
  } else {
    intersectionLegacy(shape, ic, distContour);
  }
}

float resolveHatchAngleDeg(RShape shape, int ic) {
  boolean randomizeAngle = false;
  if (hatchModeFieldName != null && hatchModeFieldName.equals("PARALLEL")) {
    randomizeAngle = true;
  }
  
  if (shape == null) return 0;
  RPoint[] sb = shape.getBoundsPoints();
  if (sb == null || sb.length < 3) return 0;
  float dx = sb[2].x - sb[0].x;
  float dy = sb[2].y - sb[0].y;
  float baseDeg = degrees(atan2(dy, dx));
  
  if (randomizeAngle) {
    return baseDeg + 90 * (int)random(0, 2);
  }
  
  if (hatchAngleMode != null && hatchAngleMode.equals("AUTO")) {
    return baseDeg;
  }
  return angle;
}

int resolvePEmbroiderHatchMode(String fieldName, int fallback) {
  if (fieldName == null || fieldName.length() == 0) return fallback;
  try {
    java.lang.reflect.Field f = PEmbroiderGraphics.class.getField(fieldName);
    return f.getInt(null);
  } catch (Exception e) {
    return fallback;
  }
}

void setPEmbroiderHatchAngleDegSafe(float angleDeg) {
  ensurePE();
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("hatchAngleDeg", float.class);
    m.invoke(E, angleDeg);
    return;
  } catch (Exception e) {
  }
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("hatchAngle", float.class);
    m.invoke(E, radians(angleDeg));
  } catch (Exception e) {
  }
}

void setPEmbroiderFloatFieldSafe(String fieldName, float value) {
  ensurePE();
  try {
    java.lang.reflect.Field f = E.getClass().getField(fieldName);
    try {
      f.setFloat(null, value);
    } catch (Exception ex) {
      f.setFloat(E, value);
    }
  } catch (Exception e) {
  }
}

void setPEmbroiderIntFieldSafe(String fieldName, int value) {
  ensurePE();
  try {
    java.lang.reflect.Field f = E.getClass().getField(fieldName);
    try {
      f.setInt(null, value);
    } catch (Exception ex) {
      f.setInt(E, value);
    }
  } catch (Exception e) {
  }
}

void setPEmbroiderObjectFieldSafe(String fieldName, Object value) {
  ensurePE();
  try {
    java.lang.reflect.Field f = E.getClass().getField(fieldName);
    try {
      f.set(null, value);
    } catch (Exception ex) {
      f.set(E, value);
    }
  } catch (Exception e) {
  }
}

void drawShapeOnPEmbroiderSafe(PShape s) {
  ensurePE();
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("shape", PShape.class, float.class, float.class);
    m.invoke(E, s, 0.0f, 0.0f);
    return;
  } catch (Exception e) {
  }
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("shape", PShape.class, int.class, int.class);
    m.invoke(E, s, 0, 0);
    return;
  } catch (Exception e) {
  }
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("shape", PShape.class);
    m.invoke(E, s);
  } catch (Exception e) {
  }
}

ArrayList<ArrayList<PVector>> getPEmbroiderPolylinesSafe() {
  ensurePE();
  try {
    java.lang.reflect.Field f = E.getClass().getField("polylines");
    Object v = f.get(E);
    return (ArrayList<ArrayList<PVector>>) v;
  } catch (Exception e) {
  }
  try {
    java.lang.reflect.Method m = E.getClass().getMethod("getPolylines");
    Object v = m.invoke(E);
    return (ArrayList<ArrayList<PVector>>) v;
  } catch (Exception e) {
  }
  return null;
}

ArrayList<PVector> trimPolylineBoth(ArrayList<PVector> poly, float trimStart, float trimEnd) {
  if (poly == null || poly.size() < 2) return null;
  if (trimStart <= 0 && trimEnd <= 0) return poly;
  
  float total = 0;
  for (int i = 0; i < poly.size() - 1; i++) {
    PVector a = poly.get(i);
    PVector b = poly.get(i + 1);
    if (a == null || b == null) continue;
    total += PVector.dist(a, b);
  }
  if (total <= 0) return null;
  if (trimStart + trimEnd >= total) return null;
  
  ArrayList<PVector> startTrimmed = poly;
  if (trimStart > 0) {
    float remaining = trimStart;
    int idx = 0;
    PVector p0 = poly.get(0);
    while (idx < poly.size() - 1) {
      PVector p1 = poly.get(idx + 1);
      float segLen = PVector.dist(p0, p1);
      if (segLen <= 0) {
        idx++;
        p0 = p1;
        continue;
      }
      if (remaining < segLen) {
        float t = remaining / segLen;
        PVector newStart = PVector.lerp(p0, p1, t);
        startTrimmed = new ArrayList<PVector>();
        startTrimmed.add(newStart);
        for (int j = idx + 1; j < poly.size(); j++) {
          startTrimmed.add(poly.get(j));
        }
        break;
      } else {
        remaining -= segLen;
        idx++;
        p0 = p1;
      }
    }
    if (startTrimmed == poly && remaining > 0) return null;
  }
  
  ArrayList<PVector> endTrimmed = startTrimmed;
  if (trimEnd > 0) {
    float remaining = trimEnd;
    int idx = endTrimmed.size() - 1;
    PVector p0 = endTrimmed.get(idx);
    while (idx > 0) {
      PVector p1 = endTrimmed.get(idx - 1);
      float segLen = PVector.dist(p0, p1);
      if (segLen <= 0) {
        idx--;
        p0 = p1;
        continue;
      }
      if (remaining < segLen) {
        float t = remaining / segLen;
        PVector newEnd = PVector.lerp(p0, p1, t);
        ArrayList<PVector> out = new ArrayList<PVector>();
        for (int j = 0; j < idx; j++) {
          out.add(endTrimmed.get(j));
        }
        out.add(newEnd);
        endTrimmed = out;
        break;
      } else {
        remaining -= segLen;
        idx--;
        p0 = p1;
      }
    }
    if (endTrimmed == startTrimmed && remaining > 0) return null;
  }
  
  if (endTrimmed.size() < 2) return null;
  return endTrimmed;
}

PShape pshapeFromRShape(RShape r) {
  if (r == null) return null;
  RPolygon poly = r.toPolygon();
  if (poly == null || poly.contours == null || poly.contours.length == 0) return null;
  
  PShape s = createShape();
  s.beginShape();
  for (int i = 0; i < poly.contours.length; i++) {
    RPoint[] pts = poly.contours[i].points;
    if (pts == null || pts.length == 0) continue;
    if (i > 0) s.beginContour();
    for (int j = 0; j < pts.length; j++) {
      s.vertex(pts[j].x, pts[j].y);
    }
    if (i > 0) s.endContour();
  }
  s.endShape(CLOSE);
  return s;
}

void intersectionPEmbroider(RShape shape, int ic, float distContour) {
  if (shape == null) return;
  
  RPoint lastHatchEnd = null;
  float angleDeg = resolveHatchAngleDeg(shape, ic);
  
  ensurePE();
  E.clear();
  E.noStroke();
  E.fill(0);
  boolean isPerlin = (hatchModeFieldName != null) && hatchModeFieldName.equals("PERLIN");
  boolean isVecField = (hatchModeFieldName != null) && hatchModeFieldName.equals("VECFIELD");
  if (isPerlin) {
    setPEmbroiderFloatFieldSafe("HATCH_SPACING", perlinHatchSpacing);
    setPEmbroiderFloatFieldSafe("HATCH_SCALE", perlinHatchScale);
    E.hatchSpacing(perlinHatchSpacing);
  } else if (isVecField) {
    Object vf = new MyVecField();
    setPEmbroiderIntFieldSafe("HATCH_MODE", resolvePEmbroiderHatchMode("VECFIELD", 0));
    setPEmbroiderObjectFieldSafe("HATCH_VECFIELD", vf);
    setPEmbroiderFloatFieldSafe("HATCH_SPACING", 4.0);
    E.hatchSpacing(4.0);
  } else {
    E.hatchSpacing(stepSVG);
  }
  if (!isPerlin && !isVecField) setPEmbroiderHatchAngleDegSafe(angleDeg);
  
  int mode = resolvePEmbroiderHatchMode(hatchModeFieldName, -1);
  if (mode == -1) mode = resolvePEmbroiderHatchMode("PARALLEL", -1);
  if (mode != -1) E.hatchMode(mode);
  
  PShape ps = pshapeFromRShape(shape);
  if (ps == null) {
    intersectionLegacy(shape, ic, distContour);
    return;
  }
  
  drawShapeOnPEmbroiderSafe(ps);
  
  ArrayList<ArrayList<PVector>> polys = getPEmbroiderPolylinesSafe();
  if (polys == null || polys.size() == 0) {
    intersectionLegacy(shape, ic, distContour);
    return;
  }
  
  for (int k = 0; k < polys.size(); k++) {
    ArrayList<PVector> poly = polys.get(k);
    if (poly == null || poly.size() < 2) continue;

    boolean insetPerSegment = (hatchModeFieldName != null) && hatchModeFieldName.equals("PARALLEL");
    ArrayList<PVector> working = poly;
    if (!insetPerSegment && distContour > 0) {
      ArrayList<PVector> trimmed = trimPolylineBoth(poly, distContour, distContour);
      if (trimmed == null || trimmed.size() < 2) continue;
      working = trimmed;
    }
    
    for (int i = 0; i < working.size() - 1; i++) {
      PVector a = working.get(i);
      PVector b = working.get(i + 1);
      if (a == null || b == null) continue;
      
      float dxl = b.x - a.x;
      float dyl = b.y - a.y;
      float lenLine = sqrt(dxl*dxl + dyl*dyl);
      if (insetPerSegment) {
        if (lenLine <= stepSVG + 1.0) continue;
        if (lenLine <= 0.001) continue;
      } else {
        if (lenLine <= 0.001) continue;
      }
      
      RPoint start;
      RPoint end;
      if (insetPerSegment && distContour > 0) {
        float ux = dxl / lenLine;
        float uy = dyl / lenLine;
        float inset = min(distContour, lenLine * 0.45);
        start = new RPoint(a.x + ux*inset, a.y + uy*inset);
        end = new RPoint(b.x - ux*inset, b.y - uy*inset);
      } else {
        start = new RPoint(a.x, a.y);
        end = new RPoint(b.x, b.y);
      }
      
      if (lastHatchEnd != null) {
        float distDirect = dist(lastHatchEnd.x, lastHatchEnd.y, start.x, start.y);
        float distFlipped = dist(lastHatchEnd.x, lastHatchEnd.y, end.x, end.y);
        if (distFlipped < distDirect) {
          RPoint temp = start;
          start = end;
          end = temp;
        }
      }
      
      RShape hatchLine = rshapeFromPELine(start.x, start.y, end.x, end.y);
      lastHatchEnd = end;
      formaList.add(new Forma(hatchLine, ic, 1));
    }
  }
}

void intersectionLegacy(RShape shape, int ic, float distContour) {
    RPoint[] ps = null;
    RPoint lastHatchEnd = null; // Variabile per ottimizzazione percorso (zig-zag)

  // Ottiene i punti che formano il rettangolo di delimitazione della forma
  RPoint[] sb = shape.getBoundsPoints();
  // sb[0] tipicamente è il punto in alto a sinistra (minX, minY)
  // sb[1] tipicamente è il punto in alto a destra (maxX, minY)
  // sb[2] tipicamente è il punto in basso a destra (maxX, maxY)
  // sb[3] tipicamente è il punto in basso a sinistra (minX, maxY)

  float minX = sb[0].x;
  float minY = sb[0].y;
  float maxX = sb[2].x;
  float maxY = sb[2].y;

  float hatchAngleDeg = resolveHatchAngleDeg(shape, ic);
  // Calcola la diagonale del rettangolo di delimitazione
  float diag = sqrt(pow(maxX-minX, 2) + pow(maxY-minY, 2));
  // Calcola il numero di linee in base alla dimensione della diagonale e allo step
  int num = 2 + int(diag/stepSVG);   //provarapp
  // Lunghezza delle linee di hatching
  int hatchLength = int(stepSVG * (num-1)); //provarapp
 
  // Parte dal centro del rettangolo di delimitazione
  RPoint sbCenter = new RPoint((minX+maxX)/2.0, (minY+maxY)/2.0);
  
  // Crea le linee di hatching
  for (int i = 0; i < num; i++) {
    float x1 = sbCenter.x - hatchLength/2;
    float y1 = sbCenter.y - hatchLength/2 + i*stepSVG;
    float x2 = sbCenter.x + hatchLength/2;
    float y2 = sbCenter.y - hatchLength/2 + i*stepSVG;
    float rad = radians(hatchAngleDeg);
    float cosA = cos(rad);
    float sinA = sin(rad);
    float rx1 = cosA*(x1 - sbCenter.x) - sinA*(y1 - sbCenter.y) + sbCenter.x;
    float ry1 = sinA*(x1 - sbCenter.x) + cosA*(y1 - sbCenter.y) + sbCenter.y;
    float rx2 = cosA*(x2 - sbCenter.x) - sinA*(y2 - sbCenter.y) + sbCenter.x;
    float ry2 = sinA*(x2 - sbCenter.x) + cosA*(y2 - sbCenter.y) + sbCenter.y;
    RShape iLine = rshapeFromPELine(rx1, ry1, rx2, ry2);
    
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
            float dxl = p2.x - p1.x;
            float dyl = p2.y - p1.y;
            float lenLine = sqrt(dxl*dxl + dyl*dyl);
            
            // Verifica se la linea è abbastanza lunga per essere visualizzata
            if (lenLine > stepSVG+1.0) {  // Controllo reintrodotto come richiesto  provarapp
              RShape hatchLine;
              float ux = dxl / lenLine;
              float uy = dyl / lenLine;
              float inset = min(distContour, lenLine * 0.5);
              RPoint start = new RPoint(p1.x + ux*inset, p1.y + uy*inset);
              RPoint end = new RPoint(p2.x - ux*inset, p2.y - uy*inset);
              
              // Ottimizzazione percorso (zig-zag):
              // Se invertendo la linea riduciamo la distanza dall'ultimo punto disegnato, invertiamola.
              if (lastHatchEnd != null) {
                // Calcoliamo la distanza euclidea manualmente per sicurezza
                float distDirect = dist(lastHatchEnd.x, lastHatchEnd.y, start.x, start.y);
                float distFlipped = dist(lastHatchEnd.x, lastHatchEnd.y, end.x, end.y);
                
                if (distFlipped < distDirect) {
                  // Swap start/end
                  RPoint temp = start;
                  start = end;
                  end = temp;
                }
              }
              
              hatchLine = rshapeFromPELine(start.x, start.y, end.x, end.y);
              
              // Aggiorna l'ultimo punto finale
              lastHatchEnd = end;
              
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

class MyVecField implements PEmbroiderGraphics.VectorField {
  public PVector get(float x, float y) {
    x *= 0.05;
    return new PVector(1, 0.5*sin(x));
  }
}
