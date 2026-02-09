# Plotter_60x50_Pembroider

Sketch Processing per generare GCode da SVG con hatching su plotter.

## Stato

- Parsing SVG con Geomerative mantenuto
- Geometria 2D in migrazione da Geomerative a PEmbroider

## Ultime modifiche

- **Fix Scaling Hatching**: Corretto il calcolo di `stepSVG` e `stepDisplay`. Ora la variabile `step` (es. 1.2) rappresenta correttamente la distanza in millimetri sulla carta. Il sistema calcola automaticamente la distanza in pixel corrispondente basandosi sul fattore di scala reale (mm/px).
- Hatching aggiornato per usare PEmbroider come backend delle primitive 2D
- Funzione centralizzata di conversione primitive PEmbroider → RShape
