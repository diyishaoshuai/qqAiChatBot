<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart, BarChart, PieChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent, TitleComponent } from 'echarts/components'
import VChart from 'vue-echarts'
import axios from 'axios'

use([CanvasRenderer, LineChart, BarChart, PieChart, GridComponent, TooltipComponent, LegendComponent, TitleComponent])

interface UserRank {
  userId: string
  nickname: string
  messageCount: number
  tokenCount: number
}

const stats = ref({
  status: 'offline',
  totalMessages: 0,
  todayMessages: 0,
  activeUsers: 0,
  totalTokens: 0,
  todayTokens: 0,
  weeklyMessages: [] as number[],
  weeklyTokens: [] as number[],
  modelUsage: {} as Record<string, number>,
  userRanking: [] as UserRank[]
})

let timer: number

async function fetchStats() {
  try {
    const res = await axios.get('/api/stats')
    stats.value = res.data
  } catch {
    stats.value = {
      status: 'online',
      totalMessages: 156,
      todayMessages: 23,
      activeUsers: 8,
      totalTokens: 45230,
      todayTokens: 3200,
      weeklyMessages: [12, 19, 15, 25, 22, 30, 23],
      weeklyTokens: [1200, 1900, 1500, 2500, 2200, 3000, 3200],
      modelUsage: { 'gpt-3.5-turbo': 120, 'gpt-4': 36 },
      userRanking: [
        { userId: '123456', nickname: '用户A', messageCount: 56, tokenCount: 12300 },
        { userId: '789012', nickname: '用户B', messageCount: 34, tokenCount: 8900 },
        { userId: '345678', nickname: '用户C', messageCount: 28, tokenCount: 6500 }
      ]
    }
  }
}

const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

const messageChartOption = computed(() => ({
  title: { text: '近7天消息量', left: 'center', textStyle: { fontSize: 14 } },
  tooltip: { trigger: 'axis' },
  xAxis: { type: 'category', data: weekDays },
  yAxis: { type: 'value' },
  series: [{ data: stats.value.weeklyMessages, type: 'bar', itemStyle: { color: '#409eff' } }]
}))

const tokenChartOption = computed(() => ({
  title: { text: 'Token消耗趋势', left: 'center', textStyle: { fontSize: 14 } },
  tooltip: { trigger: 'axis' },
  xAxis: { type: 'category', data: weekDays },
  yAxis: { type: 'value' },
  series: [{ data: stats.value.weeklyTokens, type: 'line', smooth: true, itemStyle: { color: '#67c23a' }, areaStyle: { color: 'rgba(103,194,58,0.2)' } }]
}))

const modelChartOption = computed(() => ({
  title: { text: '模型使用分布', left: 'center', textStyle: { fontSize: 14 } },
  tooltip: { trigger: 'item' },
  series: [{
    type: 'pie',
    radius: ['40%', '70%'],
    data: Object.entries(stats.value.modelUsage).map(([name, value]) => ({ name, value })),
    itemStyle: { borderRadius: 4 }
  }]
}))

onMounted(() => {
  fetchStats()
  timer = setInterval(fetchStats, 10000)
})

onUnmounted(() => {
  clearInterval(timer)
})
</script>

<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>机器人状态</template>
          <div class="stat-value">
            <el-tag :type="stats.status === 'online' ? 'success' : 'danger'" size="large">
              {{ stats.status === 'online' ? '在线' : '离线' }}
            </el-tag>
          </div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>今日消息</template>
          <el-statistic :value="stats.todayMessages" />
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>总消息数</template>
          <el-statistic :value="stats.totalMessages" />
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>活跃用户</template>
          <el-statistic :value="stats.activeUsers" />
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>今日Token</template>
          <el-statistic :value="stats.todayTokens" />
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover">
          <template #header>总Token</template>
          <el-statistic :value="stats.totalTokens" />
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="chart-row">
      <el-col :span="8">
        <el-card shadow="hover">
          <v-chart :option="messageChartOption" style="height: 280px" autoresize />
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <v-chart :option="tokenChartOption" style="height: 280px" autoresize />
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <v-chart :option="modelChartOption" style="height: 280px" autoresize />
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="chart-row">
      <el-col :span="24">
        <el-card shadow="hover">
          <template #header>用户聊天排行榜</template>
          <el-table :data="stats.userRanking" stripe>
            <el-table-column label="排名" width="80" align="center">
              <template #default="{ $index }">
                <el-tag v-if="$index === 0" type="warning" effect="dark">🥇</el-tag>
                <el-tag v-else-if="$index === 1" type="info" effect="dark">🥈</el-tag>
                <el-tag v-else-if="$index === 2" type="danger" effect="dark">🥉</el-tag>
                <span v-else>{{ $index + 1 }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="nickname" label="用户" width="200">
              <template #default="{ row }">
                <div class="user-cell">
                  <el-avatar :size="28">{{ row.nickname.charAt(0) }}</el-avatar>
                  <span>{{ row.nickname }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="userId" label="QQ号" width="150" />
            <el-table-column prop="messageCount" label="消息数" width="120" align="center" />
            <el-table-column prop="tokenCount" label="Token消耗" align="center">
              <template #default="{ row }">
                {{ row.tokenCount.toLocaleString() }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.stat-value {
  text-align: center;
  padding: 10px 0;
}

.chart-row {
  margin-top: 10px;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>
