# Plotter_60x50_Pembroider

Sketch Processing per generare GCode da SVG con hatching su plotter.

## Stato

- Parsing SVG con Geomerative mantenuto
- Geometria 2D in migrazione da Geomerative a PEmbroider

## Ultime modifiche

- **Stima Tempi (Russolino 3.0)**: Integrato modulo avanzato (`Time.pde`) per la stima precisa del tempo di esecuzione del GCode. Calcola tempi di movimento, accelerazioni e cambi utensile basandosi sui parametri fisici della macchina (FluidNC).
- **Ottimizzazione Hatching**: Implementato algoritmo "zig-zag" (serpentina) intelligente per le linee di riempimento. Il sistema inverte automaticamente la direzione delle linee quando ciò riduce il percorso a vuoto (pen-up travel), minimizzando i tempi di esecuzione del plotter.
- **Preview Interattiva**: Aggiunta modalità di visualizzazione passo-passo a fine elaborazione.
  - **Tasto 1**: Avanza di uno step (mostra contorno o singola linea hatching con punti start/end).
  - **Tasto 2**: Torna indietro di uno step.
  - **Tasto 3**: Completa la forma corrente o passa alla successiva.
  - **Tasto 4**: Torna all'inizio della forma corrente o alla precedente.
  - **Tasto 9**: Mostra tutto il disegno completo.
- **Fix Scaling Hatching**: Corretto il calcolo di `stepSVG` e `stepDisplay`. Ora la variabile `step` (es. 1.2) rappresenta correttamente la distanza in millimetri sulla carta. Il sistema calcola automaticamente la distanza in pixel corrispondente basandosi sul fattore di scala reale (mm/px).
- Hatching aggiornato per usare PEmbroider come backend delle primitive 2D
- Funzione centralizzata di conversione primitive PEmbroider → RShape
