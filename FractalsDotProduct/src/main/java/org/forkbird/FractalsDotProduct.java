package org.forkbird;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.nio.file.Files;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.IntStream;
import java.util.stream.Stream;

import static java.util.Comparator.comparing;
import static java.util.Comparator.reverseOrder;
import static java.util.List.copyOf;
import static java.util.stream.Collectors.*;

public class FractalsDotProduct {

    static final DateTimeFormatter dateTimeFormatter = DateTimeFormatter.ofPattern("yyyy.MM.dd HH:mm:ss").withZone(ZoneId.systemDefault());
    private static final int fractalSize = 5;
    private static final int bigDecimalScale = 4;
    private static final BigDecimal minAfterCosine = new BigDecimal("0.9");
    public static final RoundingMode roundingMode = RoundingMode.DOWN;

    public static void main(String[] args) throws IOException {
        if (args.length != 8) {
            throw new IllegalArgumentException("syntax: file minPatternSize maxPatternSize minCosine minLengthRatio minCosineResults calculateAll stopWhenFound");
        }
        File file = new File(args[0]);
        int maxPatternSize = Integer.parseInt(args[1]);
        int minPatternSize = Integer.parseInt(args[2]);
        BigDecimal cosineMinValue = new BigDecimal(args[3]);
        BigDecimal minLengthRatio = new BigDecimal(args[4]);
        int minCosineResults = Integer.parseInt(args[5]);
        boolean calculateAll = Boolean.parseBoolean(args[6]);
        boolean stopWhenFound = Boolean.parseBoolean(args[7]);

        for (int i = maxPatternSize; i >= minPatternSize; i--) {
            System.out.printf("Processing pattern size: %d%n", i);
            boolean fileWritten;
            if (file.isDirectory()) {
                fileWritten = processFiles(file, i, cosineMinValue, minLengthRatio, minCosineResults, calculateAll);
            } else {
                fileWritten = processOneFile(file, i, cosineMinValue, minLengthRatio, minCosineResults, calculateAll);
            }
            if (fileWritten && stopWhenFound)
                break;
        }
    }

    private static boolean processFiles(File file, int patternSize, BigDecimal cosineMinValue, BigDecimal minLengthRation, int minCosineResults, boolean calculateAll) {
        File[] files = file.listFiles(f -> !f.isDirectory() && f.getName().endsWith(".pro"));
        return Arrays.stream(files != null ? files : new File[]{})
                .map(f -> {
                    try {
                        return processOneFile(f, patternSize, cosineMinValue, minLengthRation, minCosineResults, calculateAll);
                    } catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                })
                .toList().stream()
                .filter(b -> b)
                .findFirst()
                .orElse(false);
    }

    private static boolean processOneFile(File file, int patternSize, BigDecimal cosineMinValue, BigDecimal minLengthRation, int minCosineResults, boolean calculateAll) throws IOException {
        System.out.println(file);
        List<CosineResult> cosineResults = processFile(file, patternSize, cosineMinValue, minLengthRation, calculateAll);
        if (calculateAll || cosineResults.size() >= minCosineResults) {
            cosineResults
                    .stream().limit(calculateAll ? Long.MAX_VALUE : minCosineResults)
                    .forEach(e -> System.out.printf("Cosine: %s%nLengthRatio: %s%nBase: %s%nTarget: %s%nAfter base: %s%nAfter target: %s%nAfter cosine: %s%n%n", e.cosine, e.lengthRatio, e.base, e.target, e.afterBase, e.afterTarget, e.afterCosine));

            Map<Boolean, Long> collect = cosineResults.stream()
                    .filter(cr -> cr.afterCosine != null)
                    .collect(partitioningBy(cr -> cr.afterCosine.compareTo(minAfterCosine) > 0, counting()));
            if (collect.get(false) != null && collect.get(false) > 0) {
                System.out.printf("Forecast success: %s%n%n".formatted(BigDecimal.valueOf(collect.get(true)).divide(BigDecimal.valueOf(collect.get(false)), bigDecimalScale, roundingMode)));
            }

            writeToFile(file, cosineResults.getFirst().base.fractals.getLast().dateTime.toLocalDate().toString(), patternSize, prepareCsv(cosineResults, minCosineResults, calculateAll));
            return true;
        } else {
            System.out.printf("CosineResults < %d%n", minCosineResults);
            return false;
        }
    }

    private static void writeToFile(File file, String date, int patternSize, List<String> lines) throws IOException {
        File output = File.createTempFile("%s_%s_%s_".formatted(file.getName(), patternSize, date), ".csv", file.getParentFile());
        System.out.println(output);
        FileWriter writer = new FileWriter(output);
        lines.forEach(str -> {
            try {
                writer.write("%s\n".formatted(str));
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        });
        writer.close();
    }

    private static List<String> prepareCsv(List<CosineResult> cosineResults, int minCosineResults, boolean calculateAll) {
        return Stream.concat(
                cosineResults.stream()
                        .filter(cr -> cr.afterTarget != null)
                        .limit(calculateAll ? Long.MAX_VALUE : minCosineResults)
                        .map(CosineResult::sorted)
                        .flatMap(cr -> IntStream.range(-1, cr.base.fractals.size() * 2 - 1)
                                .mapToObj(i -> createChart(cr, i))
                        ),
                cosineResults.stream()
                        .filter(cr -> cr.afterTarget != null)
                        .limit(calculateAll ? Long.MAX_VALUE : minCosineResults)
                        .map(CosineResult::sorted)
                        .map(cr -> cr.afterTarget.calculateLinearRegressionA())
                        .sorted()
                        .map(BigDecimal::toString)
        ).toList();
    }

    private static String createChart(CosineResult cr, int i) {
        if (i == -1) {
            return "Cosine base X target:;%s;after_target lrA:;%s%sbase_date;base_value;base_change;target_date;target_value;target_change".formatted(cr.base.cosine(cr.target), cr.afterTarget.calculateLinearRegressionA(), "\n");
        }
        List<Fractal> base = cr.base.fractals;
        List<Fractal> target = cr.target.fractals;
        int size = base.size();
        if (i < size) {
            return base.get(i).dateTime + ";" + base.get(i).value + ";" + base.get(i).change + ";" +
                    target.get(i).dateTime + ";" + target.get(i).value + ";" + target.get(i).change;
        } else {
            FractalsPattern afterBase = cr.afterBase;
            FractalsPattern afterTarget = cr.afterTarget;
            if (afterBase != null && afterTarget != null)
                return afterBase.fractals.get(i - size + 1).dateTime + ";" + afterBase.fractals.get(i - size + 1).value + ";;" +
                        afterTarget.fractals.get(i - size + 1).dateTime + ";" + afterTarget.fractals.get(i - size + 1).value + ";" + afterTarget.fractals.get(i - size + 1).change;
            else if (afterTarget != null)
                return ";;;" + afterTarget.fractals.get(i - size + 1).dateTime + ";" + afterTarget.fractals.get(i - size + 1).value + ";" + afterTarget.fractals.get(i - size + 1).change;
            else
                return "";
        }
    }

    static List<CosineResult> processFile(File file, int patternSize, BigDecimal cosineMinValue, BigDecimal minLengthRation, Boolean calculateAll) throws IOException {
        try (Stream<String> lines = Files.lines(file.toPath())) {
            return process(lines, patternSize, cosineMinValue, minLengthRation, calculateAll);
        }
    }

    static List<CosineResult> process(Stream<String> lines, int patternSize, BigDecimal cosineMinValue, BigDecimal minLengthRation, Boolean calculateAll) {
        return ((Function<Stream<String>, List<HighLow>>) FractalsDotProduct::toHighLows)
                .andThen(FractalsDotProduct::fractals)
                .andThen(FractalsDotProduct::valueDiff)
                .andThen(fractals -> fractalsPatterns(fractals, patternSize))
                .andThen(fractalsPatterns -> calculateAll
                        ? FractalsDotProduct.calculateAllCosines(fractalsPatterns, cosineMinValue, minLengthRation)
                        : FractalsDotProduct.calculateCosines(fractalsPatterns, cosineMinValue, minLengthRation))
                .apply(lines);
    }

    static List<CosineResult> calculateAllCosines(List<FractalsPattern> fractalsPatterns, BigDecimal cosineMinValue, BigDecimal minLengthRation) {
        return fractalsPatterns.stream()
                .parallel()
                .flatMap(base -> cosineResultStream(fractalsPatterns, base))
                .filter(cr -> cr.cosine.compareTo(cosineMinValue) >= 0)
                .filter(cr -> cr.lengthRatio.compareTo(minLengthRation) >= 0)
                .map(cr -> new CosineResult(
                        cr.base,
                        cr.target,
                        cr.cosine,
                        cr.lengthRatio,
                        findFollowingFractalPattern(fractalsPatterns, cr.base),
                        findFollowingFractalPattern(fractalsPatterns, cr.target),
                        null))
                .map(cr -> new CosineResult(
                        cr.base,
                        cr.target,
                        cr.cosine,
                        cr.lengthRatio,
                        cr.afterBase,
                        cr.afterTarget,
                        cr.afterBase != null ? cr.afterBase.cosine(cr.afterTarget) : null
                ))
                .sorted(comparing(o -> o.cosine, reverseOrder()))
                .toList();
    }

    private static FractalsPattern findFollowingFractalPattern(List<FractalsPattern> fractalsPatterns, FractalsPattern fractalsPattern) {
        return fractalsPatterns.stream()
                .parallel()
                .filter(fractalsPattern::isBefore)
                .findFirst().orElse(null);
    }

    private static Stream<CosineResult> cosineResultStream(List<FractalsPattern> fractalsPatterns, FractalsPattern base) {
        return fractalsPatterns.stream()
                .parallel()
                .filter(target -> !target.equals(base))
                .map(target -> new CosineResult(
                        base,
                        target,
                        base.cosine(target),
                        base.lengthRatio(target),
                        null,
                        null,
                        null)
                );
    }

    static List<CosineResult> calculateCosines(List<FractalsPattern> fractalPatterns, BigDecimal cosineMinValue, BigDecimal minLengthRation) {
        var lastFractalPattern = fractalPatterns.getFirst();
        return fractalPatterns.stream()
                .parallel()
                .filter(fp -> !fp.equals(lastFractalPattern))
                .map(fp -> new CosineResult(
                        lastFractalPattern,
                        fp,
                        lastFractalPattern.cosine(fp),
                        lastFractalPattern.lengthRatio(fp),
                        null,
                        findFollowingFractalPattern(fractalPatterns, fp),
                        null)
                )
                .filter(cr -> cr.cosine.compareTo(cosineMinValue) >= 0)
                .filter(cr -> cr.lengthRatio.compareTo(minLengthRation) >= 0)
                .sorted(comparing(o -> o.cosine, reverseOrder()))
                .toList();
    }

    static List<FractalsPattern> fractalsPatterns(List<Fractal> fractals, int patternSize) {
        return IntStream.range(0, fractals.size() - patternSize + 1)
                .mapToObj(start -> fractals.subList(start, start + patternSize))
                .parallel()
                .filter(list -> list.size() == patternSize)
                .map(FractalsPattern::new)
                .toList();
    }

    static List<Fractal> fractals(List<HighLow> highLows) {
        return IntStream.range(0, highLows.size() - fractalSize + 1)
                .mapToObj(start -> highLows.subList(start, start + fractalSize))
                .parallel()
                .map(FractalsDotProduct::toFractal)
                .filter(Optional::isPresent)
                .map(Optional::get)
                .collect(toList());
    }

    static List<Fractal> valueDiff(List<Fractal> fractals) {
        List<Fractal> changes = new LinkedList<>();
        for (int i = fractals.size() - 2; i >= 0; i--) {
            Fractal current = fractals.get(i);
            Fractal last = fractals.get(i + 1);
            try {
                changes.add(new Fractal(current.dateTime, current.value, current.value.subtract(last.value).divide(last.value, bigDecimalScale, roundingMode)));
            } catch (ArithmeticException ex) {
                System.err.println(current);
                System.err.println(last);
//                fractals.forEach(System.out::println);
                throw ex;
            }
        }
        changes.sort((o1, o2) -> o2.dateTime.compareTo(o1.dateTime));
        return changes;
    }

    static List<HighLow> toHighLows(Stream<String> lines) {
        return lines
                .parallel()
                .map(FractalsDotProduct::toHighLow)
                .sorted(comparing(o -> o.dateTime, reverseOrder()))
                .toList();
    }

    private static Optional<Fractal> toFractal(List<HighLow> highLows) {
        HighLow middleHL = highLows.get(2);
        boolean isUpFractal = isUpFractal(highLows, middleHL);
        boolean isDownFractal = isDownFractal(highLows, middleHL);
        return createFractal(middleHL, isUpFractal, isDownFractal);
    }

    private static boolean isDownFractal(List<HighLow> highLows, HighLow middleHL) {
        BigDecimal l1 = highLows.get(0).low;
        BigDecimal l2 = highLows.get(1).low;
        BigDecimal hl = middleHL.low;
        BigDecimal l4 = highLows.get(3).low;
        BigDecimal l5 = highLows.get(4).low;
        return l1.compareTo(hl) > 0 && l2.compareTo(hl) > 0 && hl.compareTo(l4) < 0 && hl.compareTo(l5) < 0;
    }

    private static boolean isUpFractal(List<HighLow> highLows, HighLow middleHL) {
        BigDecimal h1 = highLows.get(0).high;
        BigDecimal h2 = highLows.get(1).high;
        BigDecimal hf = middleHL.high;
        BigDecimal h4 = highLows.get(3).high;
        BigDecimal h5 = highLows.get(4).high;
        return h1.compareTo(hf) < 0 && h2.compareTo(hf) < 0 && hf.compareTo(h4) > 0 && hf.compareTo(h5) > 0;
    }

    private static Optional<Fractal> createFractal(HighLow middleHL, boolean isUpFractal, boolean isDownFractal) {
        if (isUpFractal) {
            return Optional.of(new Fractal(middleHL.dateTime, middleHL.high, null));
        } else if (isDownFractal) {
            return Optional.of(new Fractal(middleHL.dateTime, middleHL.low, null));
        } else {
            return Optional.empty();
        }
    }

    private static HighLow toHighLow(String line) {
        String[] split = line.split(",");
        if (split.length < 3) {
            throw new IllegalArgumentException(line);
        }
        return new HighLow(ZonedDateTime.parse(split[0].trim(), dateTimeFormatter), new BigDecimal(split[1].trim()), new BigDecimal(split[2].trim()));
    }

    record HighLow(ZonedDateTime dateTime, BigDecimal high, BigDecimal low) {
    }

    record Fractal(ZonedDateTime dateTime, BigDecimal value, BigDecimal change) {
    }

    record FractalsPattern(List<Fractal> fractals) {

        FractalsPattern {
            fractals = copyOf(fractals);
        }

        BigDecimal dotProduct(FractalsPattern fractalsPattern) {
            return IntStream.range(0, fractals.size())
                    .mapToObj(index -> fractals.get(index).change.multiply(fractalsPattern.fractals.get(index).change))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
        }

        BigDecimal length() {
            return fractals.stream()
                    .map(f -> f.change.multiply(f.change))
                    .reduce(BigDecimal.ZERO, BigDecimal::add)
                    .sqrt(MathContext.DECIMAL64);
        }

        BigDecimal lengthRatio(FractalsPattern fractalsPattern) {
            var thisLength = length();
            var otherLength = fractalsPattern.length();
            if (thisLength.compareTo(otherLength) > 0)
                return otherLength.divide(thisLength, bigDecimalScale, roundingMode);
            else
                return thisLength.divide(otherLength, bigDecimalScale, roundingMode);

        }

        BigDecimal cosine(FractalsPattern fractalsPattern) {
            return fractalsPattern != null ? dotProduct(fractalsPattern).divide(length().multiply(fractalsPattern.length()), bigDecimalScale, roundingMode) : null;
        }

        BigDecimal calculateLinearRegressionA() {
            var y = fractals.stream()
                    .map(f -> f.value.doubleValue())
                    .toList();
            var xAvg = IntStream.range(1, y.size() + 1).mapToDouble(d -> d).average().orElseThrow();
            var yAvg = y.stream().mapToDouble(d -> d).average().orElseThrow();
            record LinearRegressionData(double xy, double xx) {
            }
            return IntStream.range(1, y.size() + 1)
                    .mapToObj(i -> new LinearRegressionData((y.get(i - 1) - yAvg) * (i - xAvg), Math.pow(i - xAvg, 2.0)))
                    .reduce((lr1, lr2) -> new LinearRegressionData(lr1.xy + lr2.xy, lr1.xx + lr2.xx))
                    .map(lr -> BigDecimal.valueOf(lr.xy / lr.xx).setScale(bigDecimalScale, roundingMode))
                    .orElseThrow();
        }

        int fractalsCount() {
            return fractals.size();
        }

        boolean isBefore(FractalsPattern fractalsPattern) {
            return fractals.getFirst().dateTime.equals(fractalsPattern.fractals.get(fractalsPattern.fractalsCount() - 1).dateTime);
        }

        public FractalsPattern sort() {
            return new FractalsPattern(fractals.stream().sorted(comparing(o -> o.dateTime)).collect(toList()));
        }

        @Override
        public String toString() {
            return "FractalsPattern{" +
                    "fractalsCount=" + fractalsCount() +
                    ", firstFractalDateTime=" + fractals.get(fractalsCount() - 1).dateTime.toLocalDate() +
                    ", firstFractalValue=" + fractals.get(fractalsCount() - 1).value +
                    ", lastFractalDateTime=" + fractals.getFirst().dateTime.toLocalDate() +
                    ", lastFractalValue=" + fractals.getFirst().value +
                    '}';
        }
    }

    record CosineResult(FractalsPattern base,
                        FractalsPattern target,
                        BigDecimal cosine,
                        BigDecimal lengthRatio,
                        FractalsPattern afterBase,
                        FractalsPattern afterTarget,
                        BigDecimal afterCosine) {

        CosineResult sorted() {
            return new CosineResult(
                    base.sort(),
                    target.sort(),
                    cosine,
                    lengthRatio,
                    afterBase != null ? afterBase.sort() : null,
                    afterTarget != null ? afterTarget.sort() : null,
                    afterCosine);
        }

    }
}