import { RehearsalLinkProject } from '../models/RehearsalLinkProject';

export type RootStackParamList = {
  ProjectList: undefined;
  Studio: { project?: RehearsalLinkProject };
  AIAnalysis: { project: RehearsalLinkProject };
  Settings: undefined;
};
