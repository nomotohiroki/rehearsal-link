import * as FileSystem from 'expo-file-system';
import { RehearsalLinkProject } from '../models/RehearsalLinkProject';
import { v4 as uuidv4 } from 'uuid';

// TS workaround for documentDirectory property access if types are acting up
const documentDirectory = FileSystem.documentDirectory;

const PROJECTS_DIR = (documentDirectory || '') + 'RehearsalLinkProjects/';

// Ensure the directory exists
const ensureDirectory = async () => {
  const dirInfo = await FileSystem.getInfoAsync(PROJECTS_DIR);
  if (!dirInfo.exists) {
    await FileSystem.makeDirectoryAsync(PROJECTS_DIR, { intermediates: true });
  }
};

export const createProject = async (audioUri: string, duration: number = 0): Promise<RehearsalLinkProject> => {
  await ensureDirectory();
  const id = uuidv4();
  const projectDir = PROJECTS_DIR + id + '/';
  await FileSystem.makeDirectoryAsync(projectDir, { intermediates: true });

  const fileName = 'audio.m4a'; // Or get extension from URI
  const destUri = projectDir + fileName;
  await FileSystem.copyAsync({ from: audioUri, to: destUri });

  const newProject: RehearsalLinkProject = {
    id,
    name: 'New Rehearsal ' + new Date().toLocaleDateString(),
    audioFileName: fileName,
    segments: [],
    createdAt: new Date().toISOString(),
    modifiedAt: new Date().toISOString(),
    summary: '',
    fullTranscription: '',
  };

  await saveProject(newProject);
  return newProject;
};

export const saveProject = async (project: RehearsalLinkProject): Promise<void> => {
  await ensureDirectory();
  const projectDir = PROJECTS_DIR + project.id + '/';
  // Ensure project dir exists too (in case of restore/sync issues)
  const dirInfo = await FileSystem.getInfoAsync(projectDir);
  if (!dirInfo.exists) {
    await FileSystem.makeDirectoryAsync(projectDir, { intermediates: true });
  }

  const metaPath = projectDir + 'metadata.json';
  await FileSystem.writeAsStringAsync(metaPath, JSON.stringify(project));
};

export const loadProjects = async (): Promise<RehearsalLinkProject[]> => {
  await ensureDirectory();
  const items = await FileSystem.readDirectoryAsync(PROJECTS_DIR);
  const projects: RehearsalLinkProject[] = [];

  for (const item of items) {
    const projectDir = PROJECTS_DIR + item + '/';
    const metaPath = projectDir + 'metadata.json';
    try {
      const metaInfo = await FileSystem.getInfoAsync(metaPath);
      if (metaInfo.exists) {
        const content = await FileSystem.readAsStringAsync(metaPath);
        const project = JSON.parse(content) as RehearsalLinkProject;
        projects.push(project);
      }
    } catch (e) {
      console.warn('Failed to load project:', item, e);
    }
  }

  return projects.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
};

export const getAudioUri = (project: RehearsalLinkProject): string => {
  return PROJECTS_DIR + project.id + '/' + project.audioFileName;
};

export const deleteProject = async (projectId: string): Promise<void> => {
  const projectDir = PROJECTS_DIR + projectId + '/';
  await FileSystem.deleteAsync(projectDir, { idempotent: true });
};
