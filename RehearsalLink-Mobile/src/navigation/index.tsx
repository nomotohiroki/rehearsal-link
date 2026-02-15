import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootStackParamList } from './types';

import ProjectListScreen from '../screens/ProjectListScreen';
import StudioScreen from '../screens/StudioScreen';
import AIAnalysisScreen from '../screens/AIAnalysisScreen';
import SettingsScreen from '../screens/SettingsScreen';

const Stack = createNativeStackNavigator<RootStackParamList>();

const AppNavigator = () => {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="ProjectList" screenOptions={{ headerShown: false }}>
        <Stack.Screen name="ProjectList" component={ProjectListScreen} />
        <Stack.Screen name="Studio" component={StudioScreen} />
        <Stack.Screen name="AIAnalysis" component={AIAnalysisScreen} />
        <Stack.Screen name="Settings" component={SettingsScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;
