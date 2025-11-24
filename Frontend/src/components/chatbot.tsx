'use client';

import { useState, useEffect, useRef } from 'react';
import type { AnalysisData } from '@/lib/types';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Loader2, Send, User, Bot } from 'lucide-react';
import { ScrollArea } from './ui/scroll-area';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { authenticatedFetch } from '@/lib/api-client';

type Message = {
  role: 'user' | 'model';
  content: string;
};

export default function Chatbot({ analysisData }: { analysisData: AnalysisData }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const scrollAreaRef = useRef<HTMLDivElement>(null);

  // Initial greeting
  useEffect(() => {
    if (messages.length === 0) {
      setMessages([
        {
          role: 'model',
          content: `Hello! I've analyzed the pitch deck for **${analysisData.metadata.company_name}**. I can answer questions about their business model, market, team, or financials based on the deck and my research. What would you like to know?`
        }
      ]);
    }
  }, [analysisData, messages.length]);

  useEffect(() => {
    if (scrollAreaRef.current) {
      const viewport = scrollAreaRef.current.querySelector('div[data-radix-scroll-area-viewport]');
      if (viewport) {
        viewport.scrollTop = viewport.scrollHeight;
      }
    }
  }, [messages]);

  const handleSendMessage = async () => {
    if (!input.trim()) return;

    const userMessage: Message = { role: 'user', content: input };
    const newMessages: Message[] = [...messages, userMessage];
    setMessages(newMessages);
    setInput('');
    setIsLoading(true);

    try {
      const response = await authenticatedFetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/api/investor_chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deal_id: analysisData.metadata.deal_id,
          message: input,
          history: messages.map(m => ({ role: m.role, content: m.content }))
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to get response');
      }

      const data = await response.json();
      setMessages((prevMessages) => [...prevMessages, { role: 'model', content: data.message }]);
    } catch (e) {
      console.error(e);
      setMessages((prevMessages) => [...prevMessages, { role: 'model', content: 'Sorry, I encountered an error. Please try again.' }]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Card className="h-[70vh] flex flex-col">
      <CardHeader>
        <CardTitle className="font-headline text-2xl flex items-center gap-3">
          <Bot className="w-7 h-7 text-primary" />
          AI Analyst Chat
        </CardTitle>
        <CardDescription>Ask follow-up questions to get a deeper analysis of the startup.</CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col gap-4 overflow-hidden">
        <ScrollArea className="flex-1 pr-4" ref={scrollAreaRef}>
          <div className="space-y-4">
            {messages.map((message, index) => (
              <div
                key={index}
                className={`flex items-start gap-3 ${message.role === 'user' ? 'justify-end' : ''}`}
              >
                {message.role === 'model' && (
                  <div className="bg-primary p-2 rounded-full text-primary-foreground flex-shrink-0">
                    <Bot size={20} />
                  </div>
                )}
                <div
                  className={`max-w-[75%] rounded-lg p-4 ${message.role === 'user'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-muted text-muted-foreground'
                    }`}
                >
                  {message.role === 'model' ? (
                    <div className="prose prose-sm dark:prose-invert max-w-none prose-headings:text-muted-foreground prose-p:text-muted-foreground prose-strong:text-muted-foreground prose-li:text-muted-foreground">
                      <ReactMarkdown remarkPlugins={[remarkGfm]}>
                        {message.content}
                      </ReactMarkdown>
                    </div>
                  ) : (
                    <p className="text-base leading-relaxed">{message.content}</p>
                  )}
                </div>
                {message.role === 'user' && (
                  <div className="bg-primary p-2 rounded-full text-primary-foreground flex-shrink-0">
                    <User size={20} />
                  </div>
                )}
              </div>
            ))}
            {isLoading && (
              <div className="flex items-start gap-3">
                <div className="bg-primary p-2 rounded-full text-primary-foreground">
                  <Bot size={20} />
                </div>
                <div className="bg-muted text-muted-foreground rounded-lg p-3 flex items-center space-x-2">
                  <Loader2 className="w-5 h-5 animate-spin" />
                  <span>Thinking...</span>
                </div>
              </div>
            )}
          </div>
        </ScrollArea>
        <div className="flex items-center gap-2 pt-4 border-t">
          <Input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !isLoading && handleSendMessage()}
            placeholder="Ask me anything about this startup..."
            disabled={isLoading}
          />
          <Button onClick={handleSendMessage} disabled={isLoading || !input.trim()}>
            <Send className="w-4 h-4" />
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
