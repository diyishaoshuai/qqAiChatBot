<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

interface UserRecord {
  userId: string
  nickname: string
  messageCount: number
  tokenCount: number
  lastChatTime: string
}

const router = useRouter()
const users = ref<UserRecord[]>([])
const loading = ref(false)

async function loadUsers() {
  loading.value = true
  try {
    const res = await axios.get('/api/users')
    users.value = res.data
  } catch {
    users.value = [
      { userId: '123456', nickname: '用户A', messageCount: 56, tokenCount: 12300, lastChatTime: '2024-12-18 15:30' },
      { userId: '789012', nickname: '用户B', messageCount: 23, tokenCount: 5600, lastChatTime: '2024-12-18 14:20' }
    ]
  } finally {
    loading.value = false
  }
}

function viewChat(user: UserRecord) {
  router.push(`/records/${user.userId}`)
}

onMounted(loadUsers)
</script>

<template>
  <div class="records-page">
    <el-card shadow="hover">
      <template #header>
        <div class="header">
          <span>用户列表</span>
          <el-button type="primary" :loading="loading" @click="loadUsers">
            <el-icon><Refresh /></el-icon>
            刷新
          </el-button>
        </div>
      </template>
      
      <el-table :data="users" v-loading="loading" stripe @row-click="viewChat" style="cursor: pointer">
        <el-table-column prop="nickname" label="用户" width="200">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :size="32">{{ row.nickname.charAt(0) }}</el-avatar>
              <div>
                <div class="nickname">{{ row.nickname }}</div>
                <div class="qq">{{ row.userId }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="messageCount" label="聊天总条数" width="150" align="center" />
        <el-table-column prop="tokenCount" label="Token消耗" width="150" align="center">
          <template #default="{ row }">
            {{ row.tokenCount.toLocaleString() }}
          </template>
        </el-table-column>
        <el-table-column prop="lastChatTime" label="最后聊天时间" width="200" />
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button type="primary" link @click.stop="viewChat(row)">
              查看记录
              <el-icon><ArrowRight /></el-icon>
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<style scoped>
.records-page {
  height: 100%;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.nickname {
  font-weight: 500;
  color: #303133;
}

.qq {
  font-size: 12px;
  color: #909399;
}
</style>

