import React, { useEffect, useState } from 'react';
import { View, StyleSheet, FlatList, Alert } from 'react-native';
import { Appbar, List, FAB, Text, ActivityIndicator, Surface } from 'react-native-paper';
import { useNavigation, useIsFocused } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/types';
import { RehearsalLinkProject } from '../models/RehearsalLinkProject';
import { loadProjects, deleteProject } from '../services/StorageService';

type ProjectListNavigationProp = NativeStackNavigationProp<RootStackParamList, 'ProjectList'>;

const ProjectListScreen = () => {
  const navigation = useNavigation<ProjectListNavigationProp>();
  const isFocused = useIsFocused();
  const [projects, setProjects] = useState<RehearsalLinkProject[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchProjects = async () => {
    setLoading(true);
    try {
      const data = await loadProjects();
      setProjects(data);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isFocused) {
      fetchProjects();
    }
  }, [isFocused]);

  const handleDelete = (projectId: string) => {
    Alert.alert(
      'Delete Project',
      'Are you sure you want to delete this project?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteProject(projectId);
            fetchProjects();
          },
        },
      ]
    );
  };

  const renderItem = ({ item }: { item: RehearsalLinkProject }) => (
    <List.Item
      title={item.name}
      description={`${new Date(item.createdAt).toLocaleDateString()} ${new Date(item.createdAt).toLocaleTimeString()}`}
      left={(props) => <List.Icon {...props} icon="music-note" />}
      onPress={() => navigation.navigate('Studio', { project: item })}
      onLongPress={() => handleDelete(item.id)}
      right={(props) => <List.Icon {...props} icon="chevron-right" />}
    />
  );

  return (
    <View style={styles.container}>
      <Appbar.Header>
        <Appbar.Content title="RehearsalLink" />
        <Appbar.Action icon="cog" onPress={() => navigation.navigate('Settings')} />
      </Appbar.Header>

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" />
        </View>
      ) : projects.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text variant="titleMedium">No rehearsals yet.</Text>
          <Text variant="bodyMedium">Start a new recording to begin.</Text>
        </View>
      ) : (
        <FlatList
          data={projects}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          contentContainerStyle={styles.listContent}
        />
      )}

      <FAB
        style={styles.fab}
        icon="plus"
        onPress={() => navigation.navigate('Studio', {})}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    opacity: 0.6,
  },
  listContent: {
    paddingBottom: 80,
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
  },
});

export default ProjectListScreen;
