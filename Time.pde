
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////
// Funzione per calcolare e visualizzare il tempo di esecuzione del G-code
void calculateGCodeTime() {
  if (outFile == null || outFile.isEmpty()) {
    println("ERRORE: Percorso del file G-code non definito. Impossibile stimare il tempo.");
    return;
  }

  println("\n" + "=".repeat(60));
  println("Start time GCODE...");
  HashMap<String, Object> result = estimator.estimateFileTime(outFile);

  if ((Boolean) result.get("success")) {
    println("=".repeat(60));
    println("RUSSOLINO 3.0 - STIMA TEMPO ESECUZIONE (METODO AVANZATO)");
    println("=".repeat(60));
    println("File G-code: " + new File(outFile).getName());
    println("Tempo stimato: " + result.get("totalTimeFormatted"));
    println("Tempo (secondi): " + String.format("%.3f", (Float)result.get("totalTimeSeconds")));
    println("Righe elaborate: " + result.get("totalLines"));
    println("Comandi movimento: " + result.get("validCommands"));
    println("Tempo spindle: " + String.format("%.3f", (Float)result.get("spindleTimeSeconds")) + "s");
    println("=".repeat(60));
  } else {
    println("ERRORE DURANTE STIMA TEMPO: " + result.get("error"));
  }
  println("=".repeat(60) + "\n");
}


// --- INIZIO CLASSI PER LA STIMA DEL TEMPO (COPIATE DA claude.txt) ---

// Parametri macchina FluidNC - Russolino 3.0 (da YAML)
class RussolinoMachineParams {
    HashMap<String, Float> maxVelocity;
    HashMap<String, Float> maxAcceleration;
    float junctionDeviation = 0.02f;
    int spindleSpinupMs = 4000;
    int spindleSpindownMs = 4000;
    
    public RussolinoMachineParams() {
        maxVelocity = new HashMap<String, Float>();
        maxVelocity.put("X", 12000.0f);  // mm/min
        maxVelocity.put("Y", 12000.0f);
        maxVelocity.put("Z", 8000.0f);
        maxVelocity.put("A", 8000.0f);
        
        maxAcceleration = new HashMap<String, Float>();
        maxAcceleration.put("X", 2500.0f);  // mm/s²
        maxAcceleration.put("Y", 2500.0f);
        maxAcceleration.put("Z", 1000.0f);
        maxAcceleration.put("A", 2000.0f);
    }
}

// Classe per rappresentare un comando G-code
class GCodeCommand {
    String originalLine;
    String commandType;
    HashMap<String, Float> parameters;
    float feedrate = -1;
    boolean isValid = false;
    
    public GCodeCommand(String line) {
        originalLine = line.trim();
        parameters = new HashMap<String, Float>();
        parseLine();
    }
    
    private void parseLine() {
        if (originalLine.length() == 0) return;
        
        String cleanLine = originalLine.split(";")[0].split("\\(")[0].trim();
        if (cleanLine.length() == 0) return;
        
        try {
            Pattern cmdPattern = Pattern.compile("([GM]\\d+)", Pattern.CASE_INSENSITIVE);
            Matcher cmdMatcher = cmdPattern.matcher(cleanLine.toUpperCase());
            
            if (cmdMatcher.find()) {
                commandType = cmdMatcher.group(1);
                
                Pattern paramPattern = Pattern.compile("([XYZAFS])([+-]?\\d*\\.?\\d+)", Pattern.CASE_INSENSITIVE);
                Matcher paramMatcher = paramPattern.matcher(cleanLine.toUpperCase());
                
                while (paramMatcher.find()) {
                    String param = paramMatcher.group(1);
                    float value = Float.parseFloat(paramMatcher.group(2));
                    parameters.put(param, value);
                    
                    if (param.equals("F")) {
                        feedrate = value;
                    }
                }
                
                isValid = true;
            }
        } catch (Exception e) {
            isValid = false;
        }
    }
}

// Stimatore con solo metodo avanzato per Russolino 3.0
class RussolinoTimeEstimator {
    RussolinoMachineParams machine;
    HashMap<String, Float> currentPosition;
    float currentFeedrate = 1000.0f;
    float totalTime = 0.0f;
    int validCommands = 0;
    boolean spindleOn = false;
    float spindleTime = 0.0f;
    PApplet parent; // Riferimento al PApplet principale per usare loadStrings()
    
    public RussolinoTimeEstimator(RussolinoMachineParams machineParams, PApplet p) { // Modificato il costruttore
        machine = machineParams;
        parent = p; // Salva il riferimento al PApplet
        currentPosition = new HashMap<String, Float>();
        currentPosition.put("X", 0.0f);
        currentPosition.put("Y", 0.0f);
        currentPosition.put("Z", 0.0f);
        currentPosition.put("A", 0.0f);
    }
    
    private float calculateDistance(HashMap<String, Float> startPos, HashMap<String, Float> endPos) {
        float dx = endPos.getOrDefault("X", startPos.get("X")) - startPos.get("X");
        float dy = endPos.getOrDefault("Y", startPos.get("Y")) - startPos.get("Y");
        float dz = endPos.getOrDefault("Z", startPos.get("Z")) - startPos.get("Z");
        return (float) Math.sqrt(dx*dx + dy*dy + dz*dz);
    }
    
    // METODO AVANZATO: Calcolo con profili di velocità trapezoidali/triangolari
    private float calculateAdvancedMovementTime(float distance, float targetVelocity, String[] axes, boolean isRapid) {
        if (distance <= 0.001f) return 0.0f;
        
        // Determina la velocità effettiva considerando tutti gli assi coinvolti
        float effectiveVelocity = targetVelocity;
        float limitingAcceleration = Float.MAX_VALUE;
        
        if (isRapid) {
            effectiveVelocity = Float.MAX_VALUE;
            for (String axis : axes) {
                if (machine.maxVelocity.containsKey(axis)) {
                    effectiveVelocity = Math.min(effectiveVelocity, machine.maxVelocity.get(axis));
                }
                if (machine.maxAcceleration.containsKey(axis)) {
                    limitingAcceleration = Math.min(limitingAcceleration, machine.maxAcceleration.get(axis));
                }
            }
        } else {
            for (String axis : axes) {
                if (machine.maxVelocity.containsKey(axis)) {
                    effectiveVelocity = Math.min(effectiveVelocity, machine.maxVelocity.get(axis));
                }
                if (machine.maxAcceleration.containsKey(axis)) {
                    limitingAcceleration = Math.min(limitingAcceleration, machine.maxAcceleration.get(axis));
                }
            }
        }
        
        // Converti da mm/min a mm/s
        float velocityMmS = effectiveVelocity / 60.0f;
        
        // Calcolo del profilo di velocità con accelerazione/decelerazione
        float accelTime = velocityMmS / limitingAcceleration;
        float accelDistance = 0.5f * limitingAcceleration * accelTime * accelTime;
        
        if (distance <= 2 * accelDistance) {
            // Movimento breve - profilo triangolare
            float actualVelocity = (float) Math.sqrt(distance * limitingAcceleration);
            return 2 * actualVelocity / limitingAcceleration;
        } else {
            // Movimento lungo - profilo trapezoidale
            float constantDistance = distance - 2 * accelDistance;
            float constantTime = constantDistance / velocityMmS;
            return 2 * accelTime + constantTime;
        }
    }
    
    private String[] getActiveAxes(GCodeCommand command) {
        ArrayList<String> axes = new ArrayList<String>();
        for (String axis : Arrays.asList("X", "Y", "Z", "A")) {
            if (command.parameters.containsKey(axis)) {
                axes.add(axis);
            }
        }
        return axes.toArray(new String[0]);
    }
    
    private float processCommand(GCodeCommand command) {
        if (!command.isValid) return 0.0f;
        
        float commandTime = 0.0f;
        
        // Aggiorna feedrate se specificato
        if (command.feedrate > 0) {
            currentFeedrate = command.feedrate;
        }
        
        // Gestione comandi spindle
        if (command.commandType.equals("M3") || command.commandType.equals("M03")) {
            if (!spindleOn) {
                spindleTime += machine.spindleSpinupMs / 1000.0f;
                spindleOn = true;
            }
            return 0.0f;
        } else if (command.commandType.equals("M5") || command.commandType.equals("M05")) {
            if (spindleOn) {
                spindleTime += machine.spindleSpindownMs / 1000.0f;
                spindleOn = false;
            }
            return 0.0f;
        }
        
        // Movimenti - usa solo il metodo avanzato
        if (command.commandType.equals("G0") || command.commandType.equals("G00")) {
            HashMap<String, Float> newPosition = new HashMap<String, Float>(currentPosition);
            
            for (String axis : Arrays.asList("X", "Y", "Z", "A")) {
                if (command.parameters.containsKey(axis)) {
                    newPosition.put(axis, command.parameters.get(axis));
                }
            }
            
            float distance = calculateDistance(currentPosition, newPosition);
            String[] activeAxes = getActiveAxes(command);
            commandTime = calculateAdvancedMovementTime(distance, 0, activeAxes, true);
            
            currentPosition = newPosition;
            validCommands++;
            
        } else if (command.commandType.equals("G1") || command.commandType.equals("G01")) {
            HashMap<String, Float> newPosition = new HashMap<String, Float>(currentPosition);
            
            for (String axis : Arrays.asList("X", "Y", "Z", "A")) {
                if (command.parameters.containsKey(axis)) {
                    newPosition.put(axis, command.parameters.get(axis));
                }
            }
            
            float distance = calculateDistance(currentPosition, newPosition);
            String[] activeAxes = getActiveAxes(command);
            commandTime = calculateAdvancedMovementTime(distance, currentFeedrate, activeAxes, false);
            
            currentPosition = newPosition;
            validCommands++;
        }
        
        return commandTime;
    }
    
    public HashMap<String, Object> estimateFileTime(String filePath) {
        // Reset stato
        totalTime = 0.0f;
        validCommands = 0;
        spindleTime = 0.0f;
        spindleOn = false;
        currentPosition.put("X", 0.0f);
        currentPosition.put("Y", 0.0f);
        currentPosition.put("Z", 0.0f);
        currentPosition.put("A", 0.0f);
        currentFeedrate = 1000.0f;
        
        // Utilizza Processing's loadStrings() per leggere il file
        String[] lines;
        try {
            lines = parent.loadStrings(filePath); // Usa il riferimento al PApplet
            if (lines == null || lines.length == 0) {
                return createErrorResult("File vuoto o non leggibile");
            }
        } catch (Exception e) {
            return createErrorResult("Errore lettura file: " + e.getMessage());
        }
        
        // Elabora ogni riga
        for (String line : lines) {
            line = line.trim();
            if (line.length() == 0 || line.startsWith(";") || line.startsWith("(")) {
                continue;
            }
            
            GCodeCommand command = new GCodeCommand(line);
            float commandTime = processCommand(command);
            totalTime += commandTime;
        }
        
        // Aggiungi tempo spindle
        totalTime += spindleTime;
        
        // Risultati finali
        HashMap<String, Object> result = new HashMap<String, Object>();
        result.put("totalTimeSeconds", totalTime);
        result.put("totalTimeFormatted", formatTime(totalTime));
        result.put("totalLines", lines.length);
        result.put("validCommands", validCommands);
        result.put("spindleTimeSeconds", spindleTime);
        result.put("success", true);
        
        return result;
    }
    
    private HashMap<String, Object> createErrorResult(String errorMessage) {
        HashMap<String, Object> result = new HashMap<String, Object>();
        result.put("success", false);
        result.put("error", errorMessage);
        result.put("totalTimeSeconds", 0.0f);
        result.put("totalTimeFormatted", "00:00:00.000");
        return result;
    }
    
    // Funzione helper per formattare il tempo (può essere esterna alla classe o interna)
    private String formatTime(float seconds) {
        int hours = (int) (seconds / 3600);
        int minutes = (int) ((seconds % 3600) / 60);
        float secs = seconds % 60;
        return String.format("%02d:%02d:%06.3f", hours, minutes, secs);
    }
}
