import React, { useEffect, useState } from 'react';

const MESSAGES = [
  'Stay focused: every accurate part drives project success.',
  'Small improvements daily compound into big results.',
  'Data you can trust: check, track, deliver.',
  'Teamwork wins: share insights, move faster together.',
  'Quality first: right part, right time, right place.'
];

export function RotatingMessages() {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setIndex((i) => (i + 1) % MESSAGES.length), 5000);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="w-full">
      <div className="max-w-md">
        <h2 className="text-2xl font-bold mb-4 text-[#FFCD11]">Be your best today</h2>
        <p className="text-lg leading-relaxed text-gray-200 min-h-[4rem] transition-all">
          {MESSAGES[index]}
        </p>
      </div>
    </div>
  );
}

export default RotatingMessages;

