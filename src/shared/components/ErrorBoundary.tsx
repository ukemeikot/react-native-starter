import React, { Component, ErrorInfo, ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

interface Props {
  children: ReactNode;
  /** A static node, or a render function that receives the caught error. */
  fallback?: ReactNode | ((error: Error) => ReactNode);
  /** Hook for a crash reporter (Sentry, Bugsnag, ...). */
  onError?: (error: Error, info: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.props.onError?.(error, info);
    if (__DEV__) {
      console.error('ErrorBoundary caught an error:', error, info.componentStack);
    }
  }

  render() {
    const { hasError, error } = this.state;

    if (hasError) {
      const { fallback } = this.props;
      if (typeof fallback === 'function') {
        return fallback(error ?? new Error('Unknown error'));
      }
      return fallback ?? <View style={styles.container} />;
    }

    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: { flex: 1 },
});
