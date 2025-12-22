<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { ElMessage } from 'element-plus'
import axios from 'axios'

const config = ref({
  provider: 'openai',
  model: 'gpt-3.5-turbo',
  apiKey: '',
  baseURL: 'https://api.openai.com/v1',
  maxTokens: 1000,
  temperature: 0.7,
  maxHistoryLength: 20,
  summaryThreshold: 10,
  globalPrompt: '你必须遵守以下规则：1. 使用中文回复 2. 回复简洁明了',
  enableStream: true
})

const loading = ref(false)

const providerOptions = [
  { label: 'OpenAI', value: 'openai' },
  { label: 'DeepSeek', value: 'deepseek' }
]

const modelOptions = {
  openai: [
    { label: 'GPT-3.5-Turbo', value: 'gpt-3.5-turbo' },
    { label: 'GPT-4', value: 'gpt-4' },
    { label: 'GPT-4-Turbo', value: 'gpt-4-turbo' },
    { label: 'GPT-4o', value: 'gpt-4o' },
    { label: 'GPT-4o-mini', value: 'gpt-4o-mini' }
  ],
  deepseek: [
    { label: 'DeepSeek Chat', value: 'deepseek-chat' },
    { label: 'DeepSeek Coder', value: 'deepseek-coder' }
  ]
}

const defaultBaseURL = {
  openai: 'https://api.openai.com/v1',
  deepseek: 'https://api.deepseek.com/v1'
}

watch(() => config.value.provider, (newProvider) => {
  if (config.value) {
    config.value.baseURL = defaultBaseURL[newProvider as keyof typeof defaultBaseURL]
    const options = modelOptions[newProvider as keyof typeof modelOptions]
    if (options && options[0]) {
      config.value.model = options[0].value
    }
  }
}, { immediate: false })

async function loadConfig() {
  try {
    const res = await axios.get('/api/config')
    config.value = res.data
  } catch {
    // 使用默认值
  }
}

async function saveConfig() {
  loading.value = true
  try {
    await axios.post('/api/config', config.value)
    ElMessage.success('配置已保存')
  } catch {
    ElMessage.error('保存失败，请检查后端服务')
  } finally {
    loading.value = false
  }
}

onMounted(loadConfig)

const commands = [
  { cmd: '/help', desc: '显示指令帮助列表' },
  { cmd: '/new', desc: '清空当前对话，开始新会话' },
  { cmd: '/person <序号>', desc: '切换人格 (用法: /person 1)' },
  { cmd: '/person_ls', desc: '显示可用人格列表' }
]
</script>

<template>
  <div class="config-page">
    <el-card shadow="hover">
      <template #header>大模型配置</template>
      <el-form :model="config" label-width="140px">
        <el-form-item label="模型提供商">
          <el-select v-model="config.provider" style="width: 100%">
            <el-option v-for="opt in providerOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="模型">
          <el-select v-model="config.model" style="width: 100%">
            <el-option 
              v-for="opt in modelOptions[config.provider as keyof typeof modelOptions]" 
              :key="opt.value" 
              :label="opt.label" 
              :value="opt.value" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="API Key">
          <el-input v-model="config.apiKey" type="password" show-password placeholder="sk-..." />
        </el-form-item>
        <el-form-item label="Base URL">
          <el-input v-model="config.baseURL" placeholder="https://api.openai.com/v1" />
        </el-form-item>
        <el-form-item label="最大Token">
          <el-input-number v-model="config.maxTokens" :min="100" :max="8000" :step="100" style="width: 200px" />
        </el-form-item>
        <el-form-item label="温度">
          <el-slider v-model="config.temperature" :min="0" :max="2" :step="0.1" show-input style="max-width: 400px" />
        </el-form-item>
        <el-form-item label="分段发送">
          <el-switch v-model="config.enableStream" />
          <span class="tip">开启后长消息将按语句分段发送，更自然</span>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="hover" class="mt-20">
      <template #header>全局约束提示词</template>
      <el-input
        v-model="config.globalPrompt"
        type="textarea"
        :rows="8"
        placeholder="此提示词将约束所有人格的行为..."
      />
      <div class="tip" style="margin-top: 8px">此提示词会添加到所有人格提示词之前，用于设置全局规则</div>
    </el-card>

    <el-card shadow="hover" class="mt-20">
      <template #header>对话优化配置</template>
      <el-form :model="config" label-width="140px">
        <el-form-item label="最大历史轮数">
          <el-input-number v-model="config.maxHistoryLength" :min="5" :max="50" :step="5" style="width: 200px" />
          <span class="tip">保留最近N轮对话</span>
        </el-form-item>
        <el-form-item label="摘要压缩阈值">
          <el-input-number v-model="config.summaryThreshold" :min="5" :max="30" :step="1" style="width: 200px" />
          <span class="tip">超过N轮后自动压缩早期对话</span>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="hover" class="mt-20">
      <template #header>指令说明</template>
      <el-table :data="commands" stripe>
        <el-table-column prop="cmd" label="指令" width="180" />
        <el-table-column prop="desc" label="说明" />
      </el-table>
    </el-card>

    <div class="actions">
      <el-button type="primary" :loading="loading" @click="saveConfig">
        保存配置
      </el-button>
    </div>
  </div>
</template>

<style scoped>
.config-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.mt-20 {
  margin-top: 0;
}

.actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}

.tip {
  margin-left: 12px;
  color: #909399;
  font-size: 12px;
}
</style>
