import React, { useState, useEffect } from 'react';

const motivationalQuotes = [
  {
    text: "Success is not final, failure is not fatal: it is the courage to continue that counts.",
    author: "Winston Churchill"
  },
  {
    text: "The way to get started is to quit talking and begin doing.",
    author: "Walt Disney"
  },
  {
    text: "Innovation distinguishes between a leader and a follower.",
    author: "Steve Jobs"
  },
  {
    text: "The future belongs to those who believe in the beauty of their dreams.",
    author: "Eleanor Roosevelt"
  },
  {
    text: "Excellence is not a skill, it's an attitude.",
    author: "Ralph Marston"
  }
];

export function QuoteSection() {
  const [currentQuoteIndex, setCurrentQuoteIndex] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentQuoteIndex((prevIndex) => 
        (prevIndex + 1) % motivationalQuotes.length
      );
    }, 10000); // Change every 10 seconds

    return () => clearInterval(interval);
  }, []);

  const currentQuote = motivationalQuotes[currentQuoteIndex];

  return (
    <div className="w-full h-full flex flex-col justify-center items-center p-8 bg-gradient-to-br from-gray-100 to-gray-200">
      {/* Quote Icon */}
      <div className="mb-8">
        <div className="text-9xl text-[#FFCD11] font-serif">"</div>
      </div>

      {/* Quote Text */}
      <div className="max-w-2xl text-center mb-8">
        <p className="text-gray-900 text-2xl leading-relaxed transition-all duration-500 ease-in-out">
          {currentQuote.text}
        </p>
      </div>

      {/* Author */}
      <div className="flex items-center gap-4">
        <div className="w-14 h-14 bg-[#FFCD11] rounded-full flex items-center justify-center">
          <div className="w-12 h-12 bg-gray-900 rounded-full flex items-center justify-center">
            <div className="w-10 h-10 bg-[#FFCD11] rounded-full"></div>
          </div>
        </div>
        <span className="text-gray-900 font-bold text-xl transition-all duration-500 ease-in-out">
          {currentQuote.author}
        </span>
      </div>

      {/* Quote indicator dots */}
      <div className="flex gap-2 mt-8">
        {motivationalQuotes.map((_, index) => (
          <div
            key={index}
            className={`w-2 h-2 rounded-full transition-all duration-300 ${
              index === currentQuoteIndex 
                ? 'bg-[#FFCD11] scale-125' 
                : 'bg-gray-400'
            }`}
          />
        ))}
      </div>
    </div>
  );
}
