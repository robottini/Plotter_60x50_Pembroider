# Plotter_60x50_Pembroider

Sketch Processing per generare GCode da SVG con hatching su plotter.

## Stato

- Parsing SVG con Geomerative mantenuto
- Geometria 2D in migrazione da Geomerative a PEmbroider

## Ultime modifiche

- **Preview Interattiva**: Aggiunta modalità di visualizzazione passo-passo a fine elaborazione.
  - **Tasto 1**: Avanza di uno step (mostra contorno o singola linea hatching con punti start/end).
  - **Tasto 2**: Torna indietro di uno step.
  - **Tasto 3**: Completa la forma corrente o passa alla successiva.
  - **Tasto 4**: Torna all'inizio della forma corrente o alla precedente.
  - **Tasto 9**: Mostra tutto il disegno completo.
- **Fix Scaling Hatching**: Corretto il calcolo di `stepSVG` e `stepDisplay`. Ora la variabile `step` (es. 1.2) rappresenta correttamente la distanza in millimetri sulla carta. Il sistema calcola automaticamente la distanza in pixel corrispondente basandosi sul fattore di scala reale (mm/px).
- Hatching aggiornato per usare PEmbroider come backend delle primitive 2D
- Funzione centralizzata di conversione primitive PEmbroider → RShape
