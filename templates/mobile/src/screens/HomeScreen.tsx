import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Button, StyleSheet, Text, View } from "react-native";
import type { HealthResponse } from "@{{PROJECT_SLUG}}/shared";
import { ApiError, getHealth } from "../lib/api-client.js";

type ScreenState =
  | { status: "loading" }
  | { status: "success"; data: HealthResponse }
  | { status: "error"; message: string };

export function HomeScreen() {
  const [state, setState] = useState<ScreenState>({ status: "loading" });

  const load = useCallback(() => {
    setState({ status: "loading" });
    getHealth()
      .then((data) => setState({ status: "success", data }))
      .catch((error: unknown) => {
        const message = error instanceof ApiError ? error.message : "erro inesperado";
        setState({ status: "error", message });
      });
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{{PROJECT_NAME}}</Text>

      {state.status === "loading" && <ActivityIndicator testID="loading-indicator" />}

      {state.status === "success" && (
        <Text testID="health-status">
          API: {state.data.status} (v{state.data.version})
        </Text>
      )}

      {state.status === "error" && (
        <Text testID="health-error" style={styles.error}>
          Erro: {state.message}
        </Text>
      )}

      <Button title="Recarregar" onPress={load} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 12,
    padding: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: "600",
  },
  error: {
    color: "crimson",
  },
});
