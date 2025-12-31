# Fix Java 21 Compiler Plugin Issue

## Problem
Error: `release version 21 not supported` from `maven-compiler-plugin:3.14.0`

## Solution: Update pom.xml in Your Repositories

You need to update the `maven-compiler-plugin` configuration in both repositories:

### 1. Update `rms` repository (Gateway)
In `rms/pom.xml`, find the `maven-compiler-plugin` section and update it:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <version>3.13.0</version>  <!-- or 3.14.0, but 3.13.0 is known to work with Java 21 -->
    <configuration>
        <release>21</release>  <!-- Use 'release' instead of 'source' and 'target' -->
    </configuration>
</plugin>
```

### 2. Update `rms-service` repository
In `rms-service/pom.xml`, apply the same change.

### 3. If using a parent POM
If your projects inherit from a parent POM, you can override in the child pom.xml:

```xml
<build>
    <pluginManagement>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.13.0</version>
            </plugin>
        </plugins>
    </pluginManagement>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <configuration>
                <release>21</release>
            </configuration>
        </plugin>
    </plugins>
</build>
```

### 4. Alternative: Use Maven Properties
You can also set these properties in your pom.xml:

```xml
<properties>
    <maven.compiler.release>21</maven.compiler.release>
    <maven.compiler-plugin.version>3.13.0</maven.compiler-plugin.version>
</properties>
```

## Quick Check Commands

To check the current configuration in your repositories:

```bash
# Check rms repository
cd /path/to/rms
grep -A 10 "maven-compiler-plugin" pom.xml

# Check rms-service repository  
cd /path/to/rms-service
grep -A 10 "maven-compiler-plugin" pom.xml
```

## After Updating

1. Commit and push the changes to your repositories
2. Rebuild using your build scripts

## Temporary Workaround (Without Changing Repos)

If you can't modify the repositories immediately, you can override via command line:

```bash
mvn clean package \
  -Dmaven.compiler.release=21 \
  -Dmaven.compiler-plugin.version=3.13.0
```

But the **proper fix** is to update the pom.xml files in your repositories.

