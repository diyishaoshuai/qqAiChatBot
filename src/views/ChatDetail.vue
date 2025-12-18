<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'

interface Message {
  id: number
  role: 'user' | 'assistant'
  content: string
  time: string
  tokens?: number
}

const route = useRoute()
const router = useRouter()
const userId = route.params.userId as string
const userInfo = ref({ nickname: '', userId: '' })
const messages = ref<Message[]>([])
const loading = ref(false)
const chatContainer = ref<HTMLElement>()

async function loadChat() {
  loading.value = true
  try {
    const res = await axios.get(`/api/users/${userId}/messages`)
    userInfo.value = res.data.user
    messages.value = res.data.messages
  } catch {
    userInfo.value = { nickname: '用户', userId }
    messages.value = [
      { id: 1, role: 'user', content: '你好', time: '10:30' },
      { id: 2, role: 'assistant', content: '你好！有什么可以帮助你的吗？', time: '10:30', tokens: 45 },
      { id: 3, role: 'user', content: '给我讲个笑话', time: '10:31' },
      { id: 4, role: 'assistant', content: '好的！这是一个程序员笑话：\n\n为什么程序员总是分不清万圣节和圣诞节？\n\n因为 Oct 31 = Dec 25 （八进制的31等于十进制的25）😄', time: '10:31', tokens: 120 }
    ]
  } finally {
    loading.value = false
    await nextTick()
    scrollToBottom()
  }
}

function scrollToBottom() {
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight
  }
}

function goBack() {
  router.push('/records')
}

onMounted(loadChat)
</script>

<template>
  <div class="chat-detail">
    <div class="chat-header">
      <el-button :icon="ArrowLeft" @click="goBack">返回</el-button>
      <div class="user-title">
        <el-avatar :size="36">{{ userInfo.nickname?.charAt(0) || 'U' }}</el-avatar>
        <div>
          <div class="name">{{ userInfo.nickname || '用户' }}</div>
          <div class="id">QQ: {{ userInfo.userId || userId }}</div>
        </div>
      </div>
      <el-button :icon="Refresh" @click="loadChat" :loading="loading">刷新</el-button>
    </div>
    
    <div class="chat-container" ref="chatContainer" v-loading="loading">
      <div v-for="msg in messages" :key="msg.id" :class="['message', msg.role]">
        <div class="avatar">
          <el-avatar v-if="msg.role === 'user'" :size="36">{{ userInfo.nickname?.charAt(0) || 'U' }}</el-avatar>
          <el-avatar v-else :size="36" style="background: #409eff">AI</el-avatar>
        </div>
        <div class="content-wrapper">
          <div class="content">
            <pre>{{ msg.content }}</pre>
          </div>
          <div class="meta">
            <span class="time">{{ msg.time }}</span>
            <span v-if="msg.tokens" class="tokens">{{ msg.tokens }} tokens</span>
          </div>
        </div>
      </div>
      
      <div v-if="messages.length === 0 && !loading" class="empty">
        暂无聊天记录
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { ArrowLeft, Refresh } from '@element-plus/icons-vue'
export default { components: { ArrowLeft, Refresh } }
</script>

<style scoped>
.chat-detail {
  height: calc(100vh - 140px);
  display: flex;
  flex-direction: column;
  background: #fff;
  border-radius: 8px;
  overflow: hidden;
}

.chat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid #e4e7ed;
  background: #fafafa;
}

.user-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-title .name {
  font-weight: 600;
  font-size: 16px;
}

.user-title .id {
  font-size: 12px;
  color: #909399;
}

.chat-container {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  background: #f5f7fa;
}

.message {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
  max-width: 80%;
}

.message.user {
  flex-direction: row-reverse;
  margin-left: auto;
}

.message.assistant {
  margin-right: auto;
}

.content-wrapper {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.message.user .content-wrapper {
  align-items: flex-end;
}

.content {
  padding: 12px 16px;
  border-radius: 12px;
  max-width: 100%;
}

.message.user .content {
  background: #409eff;
  color: #fff;
  border-bottom-right-radius: 4px;
}

.message.assistant .content {
  background: #fff;
  color: #303133;
  border-bottom-left-radius: 4px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.content pre {
  margin: 0;
  white-space: pre-wrap;
  word-wrap: break-word;
  font-family: inherit;
  font-size: 14px;
  line-height: 1.6;
}

.meta {
  display: flex;
  gap: 12px;
  font-size: 12px;
  color: #909399;
}

.empty {
  text-align: center;
  padding: 60px;
  color: #909399;
}
</style>

