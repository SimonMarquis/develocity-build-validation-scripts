package com.gradle.enterprise.loader.offline;

import com.google.gson.reflect.TypeToken;
import com.gradle.enterprise.api.client.JSON;
import com.gradle.enterprise.api.model.GradleAttributes;
import com.gradle.enterprise.api.model.GradleBuildCachePerformance;
import com.gradle.enterprise.api.model.MavenAttributes;
import com.gradle.enterprise.api.model.MavenBuildCachePerformance;
import com.gradle.enterprise.loader.BuildScanDataLoader.BuildScanData;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.FileSystems;
import java.nio.file.Path;
import java.util.Optional;

import static com.gradle.enterprise.loader.BuildScanDataLoader.BuildToolType;

final class ReflectiveBuildScanDumpReader {
    private final Object buildScanDumpReader;

    // We need to instantiate the class so that the gson field is initialized.
    private final static JSON json = new JSON();

    private ReflectiveBuildScanDumpReader(Object buildScanDumpReader) {
        this.buildScanDumpReader = buildScanDumpReader;
    }

    static ReflectiveBuildScanDumpReader newInstance(Path licenseFile) {
        try {
            Class<?> buildScanDumpReaderClass = Class.forName("com.gradle.enterprise.scans.supporttools.scandump.BuildScanDumpReader");
            Method newInstance = buildScanDumpReaderClass.getMethod("newInstance", Path.class);
            Object instance = newInstance.invoke(null, licenseFile);
            return new ReflectiveBuildScanDumpReader(instance);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException("Unable to find the Build Scan dump extractor", e);
        } catch (InvocationTargetException e) {
            // We know that the real BuildScanDumpReader can only throw runtime exceptions (no checked exceptions are declared)
            throw (RuntimeException) e.getCause();
        } catch (NoSuchMethodException | IllegalAccessException e) {
            throw new RuntimeException("Unable to read Build Scan dumps: " + e.getMessage(), e);
        }
    }

    BuildToolType readBuildToolType(Path scanDump) {
        try {
            Method readBuildToolType = buildScanDumpReader.getClass().getMethod("readBuildToolType", Path.class);
            String buildToolType = (String) readBuildToolType.invoke(null, scanDump);
            return BuildToolType.valueOf(buildToolType);
        } catch (InvocationTargetException e) {
            // We know that the real BuildScanDumpReader can only throw runtime exceptions (no checked exceptions are declared)
            throw (RuntimeException) e.getCause();
        } catch (NoSuchMethodException | IllegalAccessException e) {
            throw new RuntimeException("Unable to read Build Scan dumps: " + e.getMessage(), e);
        }
    }

    BuildScanData<GradleAttributes, GradleBuildCachePerformance> readGradleBuildScanDump(Path scanDump) {
        try {
            Method extractGradleBuildScanDump = buildScanDumpReader.getClass().getMethod("readGradleBuildScanDump", Path.class);
            Object gradleBuild = extractGradleBuildScanDump.invoke(buildScanDumpReader, scanDump);
            GradleAttributes attributes = JSON.deserialize((String) gradleBuild.getClass().getField("attributes").get(gradleBuild), new TypeToken<GradleAttributes>() {
            }.getType());
            GradleBuildCachePerformance buildCachePerformance = JSON.deserialize((String) gradleBuild.getClass().getField("buildCachePerformance").get(gradleBuild), new TypeToken<GradleBuildCachePerformance>() {
            }.getType());

            return new BuildScanData<>(Optional.empty(), attributes, buildCachePerformance);
        } catch (InvocationTargetException e) {
            // We know that the real BuildScanDumpReader can only throw runtime exceptions (no checked exceptions are declared)
            throw (RuntimeException) e.getCause();
        } catch (NoSuchMethodException | NoSuchFieldException | IllegalAccessException e) {
            throw new RuntimeException("Unable to read Build Scan dump: " + e.getMessage(), e);
        }
    }

    @SuppressWarnings({"WeakerAccess", "unused"})
    BuildScanData<MavenAttributes, MavenBuildCachePerformance> readMavenBuildScanDump(Path scanDump) {
        try {
            Method extractMavenBuildScanDump = buildScanDumpReader.getClass().getMethod("readMavenBuildScanDump", Path.class);
            Object mavenBuild = extractMavenBuildScanDump.invoke(buildScanDumpReader, scanDump);
            MavenAttributes attributes = JSON.deserialize((String) mavenBuild.getClass().getField("attributes").get(mavenBuild), new TypeToken<MavenAttributes>() {
            }.getType());
            MavenBuildCachePerformance buildCachePerformance = JSON.deserialize((String) mavenBuild.getClass().getField("buildCachePerformance").get(mavenBuild), new TypeToken<MavenBuildCachePerformance>() {
            }.getType());

            return new BuildScanData<>(Optional.empty(), attributes, buildCachePerformance);
        } catch (InvocationTargetException e) {
            // We know that the real BuildScanDumpReader can only throw runtime exceptions (no checked exceptions are declared)
            throw (RuntimeException) e.getCause();
        } catch (NoSuchMethodException | NoSuchFieldException | IllegalAccessException e) {
            throw new RuntimeException("Unable to read Build Scan dump: " + e.getMessage(), e);
        }
    }

    // TODO Remove
    public static void main(String[] args) {
        ReflectiveBuildScanDumpReader extractor = ReflectiveBuildScanDumpReader.newInstance(FileSystems.getDefault().getPath("/Users/jhurne/Projects/road-tests/build-validation/gradle-enterprise.aux.prod.license"));
        BuildScanData<GradleAttributes, GradleBuildCachePerformance> result = extractor.readGradleBuildScanDump(FileSystems.getDefault().getPath("/Users/jhurne/Projects/road-tests/build-validation/gradle-enterprise-gradle-build-validation/.data/02-validate-local-build-caching-same-location/20230511T111441-645cb201/second-build_ge-solutions/sample-projects/gradle/8.x/no-ge/build-scan-8.0.2-3.12.6-1683796487697-104c8ac5-cf01-4eb6-8b2d-f447d4803249.scan"));
        System.out.println("Successfully fetched build scan dump data: " + result);
    }

}
