<script setup lang="ts">
import { ref } from 'vue'
import { useRoute } from 'vue-router'

const isCollapse = ref(false)
const route = useRoute()
</script>

<template>
  <div class="layout-wrapper" v-if="route.name === 'Login'">
    <router-view />
  </div>
  <el-container v-else class="layout-container">
    <el-aside :width="isCollapse ? '64px' : '200px'" class="aside">
      <div class="logo">
        <el-icon size="24"><ChatDotRound /></el-icon>
        <span v-show="!isCollapse">QQ ChatBot</span>
      </div>
      <el-menu
        :default-active="route.path"
        :collapse="isCollapse"
        router
        background-color="#fff"
        text-color="#606266"
        active-text-color="#409eff"
      >
        <el-menu-item index="/dashboard">
          <el-icon><DataAnalysis /></el-icon>
          <span>仪表盘</span>
        </el-menu-item>
        <el-menu-item index="/config">
          <el-icon><Setting /></el-icon>
          <span>配置管理</span>
        </el-menu-item>
        <el-menu-item index="/personas">
          <el-icon><User /></el-icon>
          <span>人格管理</span>
        </el-menu-item>
        <el-menu-item index="/records">
          <el-icon><ChatLineSquare /></el-icon>
          <span>消息记录</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <el-icon class="collapse-btn" @click="isCollapse = !isCollapse">
          <Fold v-if="!isCollapse" />
          <Expand v-else />
        </el-icon>
        <span class="page-title">{{ route.meta.title }}</span>
      </el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout-wrapper {
  min-height: 100vh;
  background: #f5f7fa;
}

.layout-container {
  height: 100vh;
}

.aside {
  background: #fff;
  border-right: 1px solid #e4e7ed;
  transition: width 0.3s;
}

.logo {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: #409eff;
  font-size: 18px;
  font-weight: bold;
  border-bottom: 1px solid #e4e7ed;
}

.header {
  background: #fff;
  display: flex;
  align-items: center;
  gap: 16px;
  border-bottom: 1px solid #e4e7ed;
}

.collapse-btn {
  cursor: pointer;
  color: #606266;
  font-size: 20px;
}

.page-title {
  color: #303133;
  font-size: 16px;
  font-weight: 500;
}

.main {
  background: #f5f7fa;
  padding: 20px;
}
</style>
