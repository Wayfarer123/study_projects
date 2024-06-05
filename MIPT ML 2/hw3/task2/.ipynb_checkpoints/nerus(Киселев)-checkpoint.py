# In Colab use this for download dataset
#if not os.path.exists("nerus_lenta.conllu.gz"):
#    !wget https://storage.yandexcloud.net/natasha-nerus/data/nerus_lenta.conllu.gz nerus_lenta.conllu.gz
#
# Also use this for use their lib
#!pip install nerus


import torch
from torch.utils.data import DataLoader, Dataset
from torch.nn.utils.rnn import pad_sequence
from nerus import load_nerus

class WordsVocabulary:
    def __init__(self, freq_threshold):
        self.idx2word = {0: '<PAD>', 1: '<BOS>', 2: '<EOS>', 3: '<UNK>'}
        self.word2idx = {'<PAD>': 0, '<BOS>': 1, '<EOS>': 2, '<UNK>': 3}
        self.freq_threshold = freq_threshold

    def __len__(self):
        return len(self.idx2word)

    def build_vocabulary(self, sents):
        frequencies = {}
        idx = 4
        for sent in sents:
            for word in sent:
                if word not in frequencies:
                    frequencies[word] = 1
                else:
                    frequencies[word] += 1
                if frequencies[word] == self.freq_threshold:
                    self.word2idx[word] = idx
                    self.idx2word[idx] = word
                    idx += 1

    def numericalize(self, tokens):
        return [self.word2idx[token] if token in self.word2idx else self.word2idx['<UNK>']
                for token in tokens]
        
    
class PosesVocabulary:
    def __init__(self):
        self.idx2pos = {0: '<PAD>', 1: '<BOS>', 2: '<EOS>'}
        self.pos2idx = {'<PAD>': 0, '<BOS>': 1, '<EOS>': 2}
        self.pos_tags = ['ADJ', 'ADV', 'INTJ', 'NOUN', 'PROPN',
                         'VERB', 'ADP', 'AUX', 'CCONJ', 'DET', 'NUM',
                         'PART', 'PRON', 'SCONJ', 'PUNCT', 'SYM', 'X']

    def __len__(self):
        return len(self.idx2pos)

    def build_vocabulary(self):
        idx = 3
        for pos in self.pos_tags:
            self.idx2pos[idx] = pos
            self.pos2idx[pos] = idx
            idx += 1

    def numericalize(self, poses):
        return [self.pos2idx[pos] for pos in poses]
    
    
class Nerus(Dataset):
    def __init__(self, n_docs=1000, filename="nerus_lenta.conllu.gz", freq_threshold=1):
        docs_generator = load_nerus('nerus_lenta.conllu.gz')
        docs = [next(docs_generator) for _ in range(n_docs)]
        # array of splitted sentences for each document from docs
        self.sents = []
        for doc in docs:
            for sent in doc.sents:
                self.sents.append([token.text for token in sent.tokens])
        # array of [poses for each sentence] for each document from docs_array
        self.sents_poses = []
        for doc in docs:
            for sent in doc.sents:
                self.sents_poses.append([token.pos for token in sent.tokens])
        # initialize vocabularies and build them
        self.words_vocab = WordsVocabulary(freq_threshold)
        self.words_vocab.build_vocabulary(self.sents)
        self.poses_vocab = PosesVocabulary()
        self.poses_vocab.build_vocabulary()

    def __len__(self):
        return len(self.sents)

    def __getitem__(self, idx):
        tokens = self.sents[idx]
        poses = self.sents_poses[idx]
        # tokens
        numericalized_tokens = [self.words_vocab.word2idx['<BOS>']]
        numericalized_tokens += self.words_vocab.numericalize(tokens)
        numericalized_tokens.append(self.words_vocab.word2idx['<EOS>'])
        source = torch.tensor(numericalized_tokens).unsqueeze(dim=-1)
        # poses
        numericalized_poses = [self.poses_vocab.pos2idx['<BOS>']]
        numericalized_poses += self.poses_vocab.numericalize(poses)
        numericalized_poses.append(self.poses_vocab.pos2idx['<EOS>'])
        target = torch.tensor(numericalized_poses).unsqueeze(dim=-1)
        return source, target
    
    
class MyCollate:
    def __init__(self, pad_idx):
        self.pad_idx = pad_idx

    def __call__(self, batch):
        features = [item[0] for item in batch]
        targets = [item[1] for item in batch]
        features = pad_sequence(features, batch_first=False, padding_value=self.pad_idx)
        targets = pad_sequence(targets, batch_first=False, padding_value=self.pad_idx)
        return features, targets
    
    
def get_loader(dataset, batch_size=8, shuffle=True):
    """Output tensor shape is [n_steps, batch_size]"""
    pad_idx = dataset.dataset.words_vocab.word2idx['<PAD>']
    loader = DataLoader(dataset=dataset,
                        batch_size=batch_size,
                        shuffle=shuffle,
                        collate_fn=MyCollate(pad_idx=pad_idx))
    return loader